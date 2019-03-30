use "json"
use "time"
// Lightning Daemon messages
primitive InitJsonQuery
primitive ManifestJsonQuery
primitive LightningEvent

type LightningMessage is (InitJsonQuery | ManifestJsonQuery | LightningEvent)
// Debug stuff
primitive Info
primitive Warn
primitive Error

type Severity is (Info | Warn | Error) 
// Process incoming JSON messages via stdin and
// send JSONs back via stdout 
// How to write LN-plugins: https://lightning.readthedocs.io/PLUGINS.html
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
  // LN daemon sends JSONs with "init" or "getmanifest" methods
  // We answer "init" with an empty JSON message 
  // The "getmanifest" query must be answered with details about
  // selected subscriptions, or in cases when new commands should
  // be processed by the LN daemon by delivering rpcmethod-fields  
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
  // take care of copying the "id" field from previous "getmanifest"
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
// Plugin communicates with the LN daemon via stdin/stdout
class Plugin
  let _env: Env

  new create(env: Env) =>
    _env = env
    _env.input(recover InputHandler(env) end, 80)
// According to this doc a timer could be used to keep an Actor alive:
// https://www.monkeysnatchbanana.com/2016/01/16/pony-patterns-waiting/
// Sadly this is currently not the case so that the plugin only 
// succeeds in sending the initial messages.
// Afterwards, the LN daemon closes it.
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
