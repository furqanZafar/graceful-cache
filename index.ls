{each} = require \prelude-ls

module.exports = ({
    async-request,
    life-span or 15000,
    replenish or 7500,
    stale-while-revalidate or true,
    stale-while-error or false
}?) ->

    # the purpose of the value-cache is to avoid making an async-request
    # the result for a cache-key is cached for {{life-span}} seconds extended in the background
    # by simultaneous requests
    value-cache = {}

    # the purpose of the request cache is to avoid performing the same request
    # especially if the cache-key is not in the value-cache & we are under a traffic spike
    # :: Map String, p Response
    request-cache = {}

    # :: String -> (String -> ErrorValueCallback -> ()) -> ErrorValueCallback -> ()
    get-or-request-and-cache: (cache-key, callback) !->

        # :: ErrorValueCallback -> ()
        perform-async-request = (listener) !->

            # create a new object in the async-request for the given cache-key
            request-cache[cache-key] = listeners: if listener then [listener] else []

            error, result <- async-request cache-key

            # call all the listeners with the error & result
            request-cache[cache-key].listeners |> each (listener) -> 
                if error

                    # in case of error, use expired value if exists
                    if stale-while-error and value-cache[cache-key]
                        listener null, value-cache[cache-key].value

                    # throw error otherwise
                    else
                        listener error, null

                else
                    listener null, result

            # update the value-cache with the latest value for the cache-key
            if !error
                value-cache[cache-key] =
                    value: result
                    expires-at: Date.now! + life-span

            # in case of error, extend the expiry of the old value in the value-cache (if any)
            else if value-cache[cache-key]
                value-cache[cache-key].expires-at = Date.now! + life-span

            delete request-cache[cache-key]

        # check if the result for the cache-key is present in the value cache
        if value-cache[cache-key]

            # value-cache hit
            if Date.now! < value-cache[cache-key].expires-at
                callback null, value-cache[cache-key].value

                # extend the expiration date of the cache (if its close to expiry), 
                # and update the result in the background
                if (value-cache[cache-key].expires-at - Date.now!) < replenish
                    value-cache[cache-key].expires-at = Date.now! + life-span
                    
                    # make the api call (in background), only if there isn't an existing one already underway
                    if !request-cache[cache-key]
                        perform-async-request!

                return

            # value-cache entry expired
            else

                # return stale data and revalidate in background, if stale-while-revalidate is true
                if stale-while-revalidate
                    callback null, value-cache[cache-key].value
                    value-cache[cache-key].expires-at = Date.now! + life-span
                    if !request-cache[cache-key]
                        perform-async-request!
                    return

                # clean value-cache if stale-while-error is false 
                # (i.e. we will not be using stale value when error happens)
                if !stale-while-error
                    delete value-cache[cache-key]

        # check if there is an ongoing request for the cache-key, if so, 
        # then listen to the existing request instead of creating a new request
        if request-cache[cache-key]
            request-cache[cache-key].listeners.push callback

        # we reach here if the cache-key is neither in the value-cache nor in the async-request
        # here we make an http request to the sonsuzdongu api
        # once the request is complete we move the data to value-cache and delete cache-key from request cahce
        else
            perform-async-request callback