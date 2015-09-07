sub handleStreamLineEvent(msg as Object)
    if msg.GetString() = "reboot" then
        rebootSystem()
    else if msg.GetString() = "resetFilestructure" then
        resetFilestructure()
    else 
        videoMode = createObject("roVideoMode")
        connection = msg.GetUserData()
        current = videoMode.GetMode()
        if videoMode.SetModeForNextBoot(msg.GetString()) then
            connection.stream.SendLine("supported")
        else
            connection.stream.SendLine("unsupported")
        end if
        videoMode.SetModeForNextBoot(current)
        connection.stream.Flush()
    end if
end sub


sub handleTCPConnectEvent(msg as Object, port as Object, connections as Object)
    stream = createObject("roTCPStream") ' always has to be rebuilt after acception
    if not connections.isNext()
        connections.reset()
    end if 
    connection = connections.next()
    connection.msg = msg
    connection.stream = stream
    connection.stream.SetUserData(connection)
    connection.stream.SetLineEventPort(port)
    if connection.stream.Accept(msg) then
        info("connected with " + msg.GetSourceAddress())
    else 
        info("connection with " + msg.GetSourceAddress() + " failed")
    end if
end sub

sub handleStreamEndEvent(msg as Object)
    info("a connection has been closed")
    if RunGarbageCollector().orphaned > 0 ' to make selfreferencing connections are deleted
        info("garbage collector removed an object")
    end if
end sub

function newConnection() As Object
    c = createObject("roAssociativeArray")
    c.msg = invalid
    c.stream = invalid
    return c
end function