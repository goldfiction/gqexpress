express = require "express"
session = require "express-session"
basicAuth = require "express-basic-auth"
FileStore = require("session-file-store")(session)
ip = require "ip"
gqpublicip = require "gqpublicip"
async = require "async"
util = require "util"
http = require "http"
https = require "https"
fs = require "fs"
moment = require "moment"
cookieParser = require 'cookie-parser'
bodyParser = require 'body-parser'
cookieSession = require 'cookie-session'
methodOverride = require 'method-override'
gqemail = require 'gqemail'
_ = require "lodash"

log = console.log
debug = console.error||util.debug
app = express()

defaultO=  # default setting, changes to this object should be in o being passed in
  config:
    environment:"development"
    server:
      port:8000
      sslport:8443
      forceSecure:true
      domain:"127.0.0.1"
      key:"resource/key.pem"
      cert:"resource/cert.pem"
      motd:"resource/motd"
      projectpath:"~/"
      sendreport:true
      sendreportemail:"glidev5@gmail.com"  # change this to your dev email, override gqemail setting if you want to use in production
    emailserver:  # modify this server setting to your email server
      user: "notify553@gmail.com"
      password: "bfjqlwbhekzvkhuy"
      host: "smtp.gmail.com"
      port: 465
      ssl: true
    general:
      jadepath:process.cwd()+"/views"
      staticpath:process.cwd()+"/public/www/"
    basicauth:
      authenticate:true
      challenge:true
      users:
        admin:1234
    session:
      secret:"secret"  # change this secret
      path:"/sessions"
  set:(app,o)->
    # overwrite here all the sets
    return app
  use:(app,o)->
    # overwrite here all the uses
    return app
  message:""


server=(o,cb)->
  o=o||{}
  o=_.merge(defaultO,o)  #o is defaultO overwritten by incoming o
  config=o.config

  gqemail.setServer o.config.emailserver

  errorHandle=(err)->
    debug err.stack
    if(o.config.server.sendreport)
      gqemail.emailit
        to: o.config.server.sendreportemail
        text: err.message+"\n\n"+err.stack
    cb err,o

  process.on 'uncaughtException',errorHandle

  startTime=Date.now()
  debug "Server Booting up..."

  app.set "env", config.environment||"development"
  app.set "port", config.server.port||80
  app.set "sslport", config.server.sslport||443
  app.set "localIp", ip.address()
  app.set "views", config.general.jadepath
  app.set "view engine", "jade"
  app=o.set(app,o)
  app.locals.deployVersion = Date.now()

  if config.basicauth.authenticate
    app.use basicAuth(config.basicauth)
  app.use express.favicon()
  app.use express.logger("dev")

  app.use methodOverride('X-HTTP-Method') #          Microsoft
  app.use methodOverride('X-HTTP-Method-Override') # Google/GData
  app.use methodOverride('X-Method-Override') #      IBM

  app.use express.urlencoded()
  app.use express.json()
  app.use cookieParser()

  secret=config.session.secret+""
  app.use session
    store: new FileStore
      path: process.cwd()+config.session.path
    secret: secret
    resave: true
    saveUninitialized: true

  app.use express.errorHandler()  if "development" is app.get("env")

  app.use (req,res,next)->
    if ((!req.secure)&&config.server.forceSecure)
      return res.redirect 'https://'+config.server.domain+":"+config.server.sslport+req.url
    next()
  app.use app.router

  app=o.use(app,o)

  app.use express.static(config.general.staticpath)

  try
    o.message += "\n"+fs.readFileSync(config.server.motd).toString()+"\n"
  catch e
    debug e

  o.message += "\n public IP: "+o.publicIp
  o.message += "\n private IP: "+ip.address()
  o.message += "\n "

  http.createServer(app).listen app.get("port"), (e1) ->
    o.message+= "\n HTTP server listening on port " + app.get("port")
    # check if https server port is given
    if config.server.sslport
      # start https server
      https.createServer(
        key: fs.readFileSync(config.server.key)
        cert: fs.readFileSync(config.server.cert)
      , app).listen app.get("sslport"), (e2) ->
        endTime=Date.now()
        timing=endTime-startTime
        o.message+= "\n HTTPS server listening on port " + app.get("sslport")
        o.message+= "\n Server Started @ " + moment().format('YYYY-MM-DD HH:mm:ss')
        o.message+= "\n Timing: " + timing
        cb e2, o
    else
      endTime=Date.now()
      timing=endTime-startTime
      o.message+= "\n Server Started @ " + moment().format('YYYY-MM-DD HH:mm:ss')
      o.message+= "\n Timing: " + timing
      cb e1, o

getIp=(o,cb)->
  gqpublicip.getPublicIp (e,publicip)->
    o.publicIp=publicip
    cb e,o

printLog=(o,cb)->
  log o.message
  cb null,o

doEmail= (o,cb)->
  if(o.config.server.sendreport)
    gqemail.emailit
      to: o.config.server.sendreportemail
      text: o.message
  cb null,o

@startServer=(o,cb)->
  async.waterfall [
    (cb)->
      cb null,o
    ,getIp
    ,server
    ,printLog
    ,doEmail
  ],cb