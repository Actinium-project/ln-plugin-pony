use "json"
use "time"

primitive InitJsonQuery
primitive ManifestJsonQuery
primitive LightningEvent

type LightningMessage is (InitJsonQuery | ManifestJsonQuery | LightningEvent)

primitive Info
primitive Warn
primitive Error

type Severity is (Info | Warn | Error) 

class InputHandler is InputNotify
  let _env: Env
  var _currentJson: String = ""
  let _emptyJson: String = "{}"
  let _manifestJson: String = """
              {
                "jsonrpc": "2.0",
                "id": 1,
                "result": {
                  "options": [],
                  "rpcmethods": [],
                  "subscriptions": [
                    "connect",
                    "disconnect"
                  ]
                }
              }
              """
  new create(env: Env) =>
    _env = env

  fun ref apply(data: Array[U8] iso) =>
    try
      let incoming = String.from_array(consume data)
      _currentJson = recover 
                        let newJson = String(_currentJson.size() + incoming.size())
                        newJson.append(_currentJson)
                        newJson.append(incoming)
                        newJson
                      end
      let doc = JsonDoc
      doc.parse(_currentJson)?
      match doc.data
        | None => _debug(Info, "no message received...continuing")
      else
        _currentJson = recover String end
        _parseJson(doc)?
      end
    end

  fun _parseJson(doc: JsonDoc)? =>
    let json = doc.data as JsonObject
    let method: String = json.data("method")? as String
    match method
      | "init" => _sendJson(InitJsonQuery, json)?
      | "getmanifest" => _sendJson(ManifestJsonQuery, json)?
    else 
      _sendJson(LightningEvent, json)?
    end

  fun _sendJson(message: LightningMessage, json: JsonObject)? =>
    match message
      | InitJsonQuery => _send(_emptyJson)
      | ManifestJsonQuery => _sendManifestAnswerJson(json)?
      | LightningEvent => _send(json.string())
    end
  
  fun _sendManifestAnswerJson(json: JsonObject)? =>
    let doc = JsonDoc
    doc.parse(_manifestJson)?
    let answer = doc.data as JsonObject
    answer.data("id") = json.data("id")? as I64
    _send(answer.string())

  fun _send(message: String) =>
    _debug(Info, "sent message: " + message)
    _env.out.print(message)

  fun _debug(severity: Severity, message: String) =>
    match severity 
      | Info => _env.err.print("INFO | " + message)
      | Warn => _env.err.print("WARN | " + message)
      | Error => _env.err.print("ERROR | " + message)
    end

class Plugin
  let _env: Env

  new create(env: Env) =>
    _env = env
    _env.input(recover InputHandler(env) end, 80)

class Looper is TimerNotify

  fun ref apply(timer: Timer, count: U64): Bool =>
    true

actor Main
    let plugin: Plugin
    let timers: Timers
    
    new create(env: Env) =>
      plugin = Plugin(env)
      timers = Timers
      let timer = Timer(Looper, 5_000_000_000, 1_000_000_000)
      timers(consume timer)

    
      
        
      

    
      


    