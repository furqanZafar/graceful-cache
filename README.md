graceful-cache
===

# Install
`npm install graceful-cache`

# Usage
```javascript
GracefulCache = require("graceful-cache")

// create a new instance of GracefulCache
keywordsCache = new GracefulCache({
    asyncRequest: (keyword, done) => {
        setTimeout(() => {
            done(null, ["term1", "term2"])
        }, 5000)
    },
    lifeSpan: 1000 * 60 * 15, // 15 seconds
    replenish: 1000 * 60 * 7 // revalidate the cache in background when a request happens 7 seconds after the value was cached
    staleWhileRevalidate: true, // in case of a miss, use stale value & update the cache in background
    staleWhileError: true, // in case of an error, use an existing cached value if exists
})

...

app.get("/search/:keyword", (req, res) => {

    // getOrRequestAndCache :: a -> ErrorValueCallback -> ()
    keywordsCache.getOrRequestAndCache(req.params.keyword, (err, results) => {
        if (err) 
            res.status(500).send(err)
        else
            res.send(results)
    })

})
```

# Flow
!["Overview"](http://i.imgur.com/6n8kngF.png?1)
!["Performing asyncRequest"](http://i.imgur.com/Rvo9zgb.png?1)
