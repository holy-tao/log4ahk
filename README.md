# log4ahk
A lightweight, highly configurable logging module for AutoHotkey based off Java's [Log4J](https://logging.apache.org/log4j/2.x/index.html).

## Usage
The core components of log4ahk are _Appenders_ and _Filters_. Appenders write logs to destinations like log files or a database and filters allow for finer control over logging behavior than the simple log level. Appenders and Filters are [callable objects](https://www.autohotkey.com/docs/v2/misc/Functor.htm) - they can be simple functions or complex stateful objects.

A dead-simple logging configuration that simply appends logs to stdout might look like:

```autohotkey
Log.To((log) => FileAppend(log.payload . "`n", "*"))
```

To ignore logs with "Unicorns" in the message, we can add a filter:
```autohotkey
Log
    .Filter((log) => !InStr(log.payload, "Unicorns"))
    .To((log) => FileAppend(log.payload . "`n", "*"))
```

We can of course use as many filters and appenders as we want:
```autohotkey
Log
    .Filter((log) => !InStr(log.payload, "Unicorns"))
    .To((log) => FileAppend(log.payload . "`n", "*"))
    .To((log) => FileAppend(log.payload . "`n", A_WorkingDir . "/script.log"))
```

In practice, we likely want to use a [`FileAppender`](./appenders/FileAppender.ahk), which can buffer its writes and does not require us to repeatedly open and reopen the file.

Once your logging is configured, you can log an event using any of the `Log.<level>` APIs:
```autohotkey
Log.Debug("A debug log")
Log.Info("Something happened!")

try {
    Log.Warn("Attempting a dangerous operation")
    DangerousOperation()
}
catch Error as err {
    Log.Error(err)
}
```

These are aliases for `LogMessage`, which you can also use if you don't know the log level ahead of time:
```autohotkey
OnError((thrown, mode) => Log.LogMessage(mode == "ExitApp" ? Log.Level.FATAL : Log.Level.ERROR, thrown))
```

### Logging Details
Fundamentally, a log event consists of a _level_ and a _payload_. The level indicates the severity of the log, and the payload is the log's message. log4ahk will also add a timestamp and _target_ for use downstream.

#### Log Levels
log4ahk defines the following log levels in `Log.Level`. Higher levels are _more severe_.

0. `OFF`
1. `TRACE`
2. `DEBUG`
3. `INFO`
4. `WARN`
5. `ERROR`
6. `FATAL`

The default log level is 3 - `INFO`, but when the Log class is initialized, it will look for an environment variable named `AHK_LOG_LEVEL` and read its value. If the value is one of the strings above or a number 0-6, that value becomes the default log level. You can also set or retrieve the log level at any time:

```autohotkey
Log.Info("Log level is " . Log.Level[Log.CurrentLevel]) ; "Log level is INFO / ERROR / etc"
Log.CurrentLevel := Log.Level.TRACE
```

Events are logged with a log level, and logging only proceeds of the event's level is greater than or equal to the configured log level. Thus by default, `DEBUG` and `TRACE` logs are ignored.

#### Log Payloads
The log's _payload_ defines its message and must be one of the following:
1. A String
2. An [Error](https://www.autohotkey.com/docs/v2/lib/Error.htm) object
3. An Object with a [`ToString`](https://www.autohotkey.com/docs/v2/lib/String.htm) method
4. A [callable object](https://www.autohotkey.com/docs/v2/misc/Functor.htm) that returns a one of the above types

Using callable objects or functions allows for [lazy logging](https://medium.com/flowe-ita/logging-should-be-lazy-bc6ac9816906), because the payload is not evaluated unless the log level indicates that we should actually log something. Thus with the default log level of `INFO`, the following code does not throw an Error:

```autohotkey
ErrorThrowingFunction(){
    throw Error("Should've used lazy logging")
}

Log.Debug(ErrorThrowingFunction)
```

This improves performance when producing the log would require calling a computationally expensive function.

#### Event Objects
Log payloads are transoformed into _log objects_ when they are sent downstream. The `Log.Event` object includes extra information like a timestamp and target information that can be used for filtering and provide additional information to appenders, should they want it.

The shape of a log object is:
```
{
    level: Integer
    payload: String
    timestamp: YYYYMMDD24HHSS timestamp
    msec: Value of A_MSec at the time of the log
    target: The value of Log.target - by default, A_ScriptName
}
```

### Filtering
When a log event is processed, every filter registered with log4ahk is called and its return value is checked. If all filters return a truthy value, the event proceeds through the pipeline. Filters can also mutate the log object, if you want.

Filters are checked in the order in which they are registered.

## Architecture
Unlike Log4J and related projects like [log4rs](https://docs.rs/log4rs/latest/log4rs/), there is no Logger heirarchy and there is no specific Encoder or Layout layer - Appenders should do this themselves.

### Lifecycle of a Log Event
log4ahk is meant to be lightweight. It will avoid evaluating log payloads whenever possible and quit from filters early if any return false.

``` mermaid
---
title: Log Event Lifecycle Flowchart
config:
  theme: redux
---
flowchart LR 
    Start(["Log Event Initiated"]) --> Level{"Event level ≥ Log level?"}
    Level -- No --> Stop(["Stop"])
    Level -- Yes --> Payload("Evaluate payload")
    Payload --> Object("Create Log.Event Object")
    Object --> Filters{"All Filters Pass?"}
    Filters -- No --> Stop(["Discard event"])
    Filters -- Yes --> Append(["Invoke appenders"])
```

When a log event is initiated, the log4ahk first checks its level. If the log's level is lower than the configured log level, it is immediately discarded. Otherwise, the payload is evaluated and a log object is created. If all filters pass, the object is sent to all configured appenders, which will encode and append the log to its final destination.