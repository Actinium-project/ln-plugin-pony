use "json"
use "time"
use "files"

// Lightning Daemon messages
primitive InitJsonQuery
primitive ManifestJsonQuery
primitive LightningEvent
primitive InvalidMessage

type LightningMessage is (InitJsonQuery | 
                          ManifestJsonQuery | 
                          LightningEvent |
                          InvalidMessage)
// Debug stuff
primitive Info
primitive Warn
primitive Error

type Severity is (Info | Warn | Error) 

actor Debugger
  let _out: OutStream

  new create(out: OutStream) =>
    _out = out

  be print(severity: Severity, message: String) =>
    match severity 
      | Info => _out.print("INFO | " + message)
      | Warn => _out.print("WARN | " + message)
      | Error => _out.print("ERROR | " + message)
    end

actor Logger
  let _env: Env

  new create(env: Env) =>
    _env = env

  be print(severity: Severity, message: String) =>
    try
      let filepath = FilePath(_env.root as AmbientAuth, "ln-plugin-pony.log")?
      with file = CreateFile(filepath) as File do
        match severity 
          | Info => file.print("INFO | " + message)
          | Warn => file.print("WARN | " + message)
          | Error => file.print("ERROR | " + message)
        end
      end
    end
    

actor LightningClient
  let _env: Env
  let _debug: Debugger
  let _emptyJson: String = "{}"
  let _logger: Logger

  new create(env: Env) =>
    _env = env
    _debug = Debugger(env.err)
    _logger = Logger(env)
    _debug.print(Info, "LN Client started")

  be send(messageType: LightningMessage, json: JsonDoc iso) =>
    let message = json.string().clone()
    match messageType
      | InitJsonQuery => _send(_emptyJson)
      | ManifestJsonQuery => _send(consume message)
    end

  fun ref _send(message: String) =>
    _env.out.print(message)
    _debug.print(Info, "Sent: " + message)
    _logger.print(Info, message)


class MessageParser
  let _out: OutStream
  let _debug: Debugger
  let _manifestJson: String = """
              {
                "jsonrpc": "2.0",
                "id": 0,
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
 
  new create(out: OutStream) =>
    _out = out
    _debug = Debugger(_out)
    _debug.print(Info, "Message Parser started")

  fun parse(message: String iso): (LightningMessage, JsonDoc iso^)? => 
    let doc = recover iso JsonDoc end
    doc.parse(consume message)?
    _createMessageTuple(consume doc)

  // LN daemon sends JSONs with "init" or "getmanifest" methods
  // We answer "init" with an empty JSON message 
  // The "getmanifest" query must be answered with details about
  // selected subscriptions, or in cases when new commands should
  // be processed by the LN daemon by delivering rpcmethod-fields  
  fun _createMessageTuple(doc: JsonDoc): (LightningMessage, JsonDoc iso^) =>
    try
      let json = doc.data as JsonObject
      _debug.print(Info, "Received: " + json.string())
      let method: String = json.data("method")? as String
      match method
        | "init" => (InitJsonQuery, recover iso JsonDoc end)
        | "getmanifest" => (ManifestJsonQuery, _prepareManifestAnswerJson(json.data("id")? as I64))
      else 
        (LightningEvent, recover iso 
                                 let returnDoc = JsonDoc
                                 returnDoc.parse(json.string())?
                                 returnDoc 
                                 end)
      end
    else
      (InvalidMessage, recover iso JsonDoc end)
    end

  fun _prepareManifestAnswerJson(id: I64): JsonDoc iso^ =>
    try 
      let doc = JsonDoc
      doc.parse(_manifestJson)?
      let json = doc.data as JsonObject
      json.data("id") = id
      doc
      recover iso 
              let d = JsonDoc
              d.parse(json.string())?
              d
            end
    else 
      recover iso JsonDoc end
    end

// Process incoming JSON messages via stdin and
// send JSONs back via stdout 
// How to write LN-plugins: https://lightning.readthedocs.io/PLUGINS.html
class InputHandler is InputNotify
  let _env: Env
  let _parser: MessageParser
  let _client: LightningClient
  let _debug: Debugger
  let _logger: Logger
  var _currentJson: String = ""

  new create(env: Env) =>
    _env = env
    _logger = Logger(env)
    _debug = Debugger(_env.err)
    _parser = MessageParser(_env.err)
    _client = LightningClient(_env)
    _debug.print(Info, "InputHandler initialized")

  fun ref apply(data: Array[U8] iso) =>
    try
      _updatePartialJson(String.from_array(consume data))
      if isJsonComplete() then
        let validJsonString = _currentJson.clone()
        _currentJson = ""
        (let messageType: LightningMessage, let message: JsonDoc iso) = _parser.parse(consume validJsonString)?
        match messageType
        | InvalidMessage => _logger.print(Warn, "message invalid")
        | InitJsonQuery => _client.send(InitJsonQuery, consume message)
        | ManifestJsonQuery => _client.send(ManifestJsonQuery, consume message)
        | LightningEvent => _logger.print(Info, "Received: " + message.string())
        end
      end
    end

  fun ref _updatePartialJson(message: String) =>
    _currentJson = recover 
                    let newJson = String(_currentJson.size() + message.size())
                    newJson.append(_currentJson)
                    newJson.append(message)
                    newJson
                  end

  fun isJsonComplete(): Bool =>
    try
      let doc = JsonDoc
      doc.parse(_currentJson)?
      true
    else
      false
    end

// Plugin communicates with the LN daemon via stdin/stdout
class Plugin
  let _env: Env
  let _debug: Debugger

  new create(env: Env) =>
    _env = env
    _debug = Debugger(_env.err)
    _env.input(recover InputHandler(env) end, 100)
    _debug.print(Info, "Plugin started")
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
    let timer = Timer(Looper, 0, 5_000_000_000)
    timers(consume timer)
