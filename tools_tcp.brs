' Handles commands sent from the client. Can be easyly extended by adding other else ifs
' 
' @param msg The occured roStreamLineEvent.
sub handleStreamLineEvent(msg as Object)
    if msg.GetString() = "reboot" then
        rebootSystem()
    else if msg.GetString() = "resetFilestructure" then
        resetFilestructure()
    ' TODO: make resolution request parsable too. For ex. with "check reolution: "
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

' Handles TCP Connection requests from a client.
'
' @param msg The occured roTCPConnectEvent
' @param port The message port that will be registered in the new roTCPStream object.
' @param connections The pool of roTCPStreams that will be used to store the new connection.
sub handleTCPConnectEvent(msg as Object, port as Object, connections as Object)
    stream = createObject("roTCPStream") ' always has to be rebuilt after last acception
    if not connections.isNext()
        connections.reset()
    end if 
    connection = connections.next()
    connection.msg = msg
    connection.stream = stream
    connection.stream.SetUserData(connection)
    connection.stream.SetLineEventPort(port)
    ' Accept must be at the end of the method, as problems occured that the first string sent wasn't handeled otherwise. 
    ' Looks like the network card waits to acknowledge the connection until the Accept is called. If the Accept is called 
    ' as late as possible, all the objects are allready build and linked so most of the work is done and the first string
    ' sent can be received.
    ' I made tests what happens if the Accept isn't called at all after a connection request was received. It looked like
    ' the network protocol sends the achnowledge anyway what would make the TCP protocol unnecessary.... (?) I'd say that
    ' there might be situations of network faults, that could signal en established TCP connection, but actualy not handle
    ' any sent strings. Using devices with this script might show reliability.
    if connection.stream.Accept(msg) then
        info("connected with " + msg.GetSourceAddress())
    else 
        info("connection with " + msg.GetSourceAddress() + " failed")
    end if
end sub

' Shows that a connection has been closed
' 
' @param msg The occured roStreamEndEvent
sub handleStreamEndEvent(msg as Object)
    ' TODO: info the connections ip
    info("a connection has been closed")
    ' GarbageColelctor must be runned as the connection is linked with the UserData of the TCPStream stored in the connection 
    ' itself. The BrightScript GarbageCollector identifies those objects as selfreferencing and unused, and deletes them. 
    if RunGarbageCollector().orphaned > 0 ' to make selfreferencing connections are deleted
        info("garbage collector removed an object")
    end if
end sub

' Pseudo object of a new connection containing all necessary infromation, and if possible build needed objects allready.
function newConnection() As Object
    c = createObject("roAssociativeArray")
    c.msg = invalid
    c.stream = invalid
    return c
end function