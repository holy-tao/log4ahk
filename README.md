# log4ahk
A lightweight, highly configurable logging module for AutoHotkey based off Java's [Log4J](https://logging.apache.org/log4j/2.x/index.html).

## Usage
The core components of log4ahk are _Loggers_, _Appenders_, and _Filters_. Loggers define individual logging pipelines. Appenders write logs to destinations like log files or a database and filters allow for finer control over logging behavior than the simple log level. Appenders and Filters are [callable objects](https://www.autohotkey.com/docs/v2/misc/Functor.htm) - they can be simple functions or complex stateful objects.

A dead-simple logging configuration that simply writes logs via [`OutputDebug`](https://www.autohotkey.com/docs/v2/lib/OutputDebug.htm) might look like:

```autohotkey
Log.Configure()
    .ToLogger(Log.Logger()
        .WithAppender((log) => OutputDebug(log.payload))
    )
```
In practice, we likely want to use a [`FileAppender`](./appenders/FileAppender.ahk), which can buffer its writes and does not require us to repeatedly open and reopen the file. To ignore logs with "Unicorns" in the message, we can add a filter:
```autohotkey
Log.Configure()
    .ToLogger(Log.Logger("Filtered")
        .Filter((log) => !InStr(log.payload, "Unicorns"))
        .WithAppender(FileAppender("filelog.log"))
    )
```

We can of course use as many loggers with as many filters and appenders as we want. We can also add global filters. Loggers can also define their own log levels. The example below explicitly sets the starting log level to `INFO` and configures a logger to log events with a severity of `ERROR` or above to the Windows Event Log. 
```autohotkey
Log.Configure(Log.Level.INFO)
    .Filter((log) => !InStr(log.payload, "Unicorns"))
    .ToLogger(
        Log.Logger("FileLogs")
            .WithAppender(FileAppender("Script-" . A_Now . ".log"))
            .WithAppender(ConsoleAppender())
            .WithAppender((log) => OutputDebug(log.payload))
    )
    .ToLogger(
        Log.Logger("WindowsEvents", Log.Level.ERROR)
            .WithAppender(WindowsEventLogAppender())
    )
```

Unlike Log4J and related projects like [log4rs](https://docs.rs/log4rs/latest/log4rs/), log4ahk has no true "logger heirarchy", but Loggers are downstream of the global configuration. If `Log.CurrentLevel` is `OFF`, no messages will be sent to any registered loggers. However, if `Log.CurrentLevel` is `TRACE`, the "WindowsEvents" logger above will still ignore events unless they have a level of `ERROR` or above.

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

0. `ALL`
1. `TRACE`
2. `DEBUG`
3. `INFO`
4. `WARN`
5. `ERROR`
6. `FATAL`
7. `OFF`

The default log level is `OFF`. You can explicitly set the log level in `Log.Configure`, but if you choose not to, it will look for an environment variable named `AHK_LOG_LEVEL` and read its value. If the value is one of the strings above or a number 0-6, that value becomes the default log level. You can also set or retrieve the log level at any time:

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
    target: The name of the logger which is processing the event
}
```

### Filtering
When a log event is processed, every filter registered with log4ahk is called and its return value is checked. If all filters return a truthy value, the event proceeds through the pipeline. Filters can also mutate the log object, if you want.

Filtering can be done globally using `Log.Filter`, or per-logger. Filters are checked in the order in which they are registered.

## Architecture
log4ahk is meant to be lightweight. It will avoid evaluating log payloads whenever possible and quit from filters early if any return false.

``` mermaid
---
config:
  theme: redux
  layout: elk
  look: neo
title: Log Event Lifecycle Flowchart
---
flowchart TB
 subgraph s1["Log.Logger"]
        LoggerLevel{"Level ≥ Logger Log level?"}
        LoggerFilters{"Logger Filters Pass?"}
        Append(["Invoke appenders"])
  end
    LoggerFilters -- Yes --> Append
    LoggerFilters -- No --> Stop(["Discard event"])
    LoggerLevel -- No ---> Stop
    LoggerLevel -- Yes --> LoggerFilters
    Start(["Log Event Initiated"]) --> Level{"Level ≥ Global Log level?"}
    Level --> GlobalFilters{"Global Filters Pass?"}
    Level -- No --> Stop
    GlobalFilters -- No --> Stop
    GlobalFilters -- Yes --> Payload("Evaluate payload")
    Payload --> Object("Create Log.Event Object")
    Object --> LoggerLevel
```

When a log event is initiated, the log4ahk first checks its level. If the log's level is lower than the configured log level, it is immediately discarded. Otherwise, the payload is evaluated and a log object is created. If all filters pass, the object is sent to all configured appenders, which will encode and append the log to its final destination.