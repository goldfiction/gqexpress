gqexpress=require "../../gqexpress"
assert=require "assert"

it "should be able to start the server",(done)->
  gqexpress.startServer  # invoke start server like this
    set:(app,o)->  # override set object like this
      app.set "doing","test"
      return app  # kindly return app back to startServer with app.sets
    use:(app,o)->  # override use object like this
      app.get "/",(req,res)->
        res.render "index",  # you can render jade in /views folder like this
          title:"gqexpress"  # meta info passed to jade and render using #{title}
      return app  # kindly return app back to startServer with app.gets
  ,(e,o)->
    console.log " All done!"  # if you see this, then the server is running correctly
    assert o.message  # check if message is filled up
    setTimeout ()->
      done e
    ,500