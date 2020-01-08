# @todo: make this dyn
(def content 
  "Characters considered part of the route"
  '(+ :w (set "-_.")))

(def sep "Separator character" "/")

(def pref "Param prefix character" ":")

(def grammar 
  "PEG grammar to match routes with"
  (peg/compile
    {:sep sep :pref pref :path ~(some ,content) 
     :param '(* :pref :path) :capture-path '(<- :path)
     :main '(some (* :sep 
                     (+ (if :param (group (* (constant :param) :pref :capture-path)))
                        (if :path (group (* (constant :path) :capture-path)))
                        (if -1 (group (* (constant :root) (constant -1)))))))}))

(defn- compile-route
  "Compiles custom grammar for one route"
  [route]
  (-> (seq [[pt p] :in (peg/match grammar route)]
           (case pt
             :root (tuple '* sep p)
             :path (tuple '* sep p) 
             :param (tuple '* sep  
                      ~(group (* (constant ,(keyword p)) 
                                 (<- (some ,content)))))))
      (array/insert 0 '*)
      (array/push -1)
      splice
      tuple
      peg/compile))

(defn- extract-args
  "Extracts arguments from peg match"
  [route-grammar uri]
  (when-let [p (peg/match route-grammar uri)]
    (table ;(flatten p))))

(defn compile-routes
  "Compiles PEG grammar for all routes"
  [routes]
  (let [res @{}]
    (loop [[route action] :pairs routes] 
        (when (string? route) (put res (compile-route route) action)))
    res))

(defn lookup 
  "Looks up uri in routes and returns action and params for the matched route"
  [compiled-routes uri]
  (var matched [])
  (loop [[grammar action] :pairs compiled-routes :while (empty? matched)]
    (when-let [args (extract-args grammar uri)] (set matched [action args])))
  matched)

(defn router
  "Creates a simple router from routes"
  [routes]
  (def compiled-routes (compile-routes routes))
  (fn [path] (lookup compiled-routes path)))


