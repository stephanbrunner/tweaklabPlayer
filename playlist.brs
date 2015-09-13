' 
' This script is used, when <mode>playlist</mode> is chosen in settings.xml. The player then plays through the playlist
' defined in playlist.xml.
' 
' Stephan Brunner
' Tweaklab
' Version 1.0
' 11.09.2015
' 
' @param settings The settings.xml converted to an Associative Array
' @param server An opened server object that will be used to comunicate with the client software
' @param connections A pool of 10 yet unused roTCPStream objects. 
Sub playlistMain(settings as Object, server as Object, connections as Object) 
    ' state used by roVideoEvent that will be triggered by roVideoPlayer
    MEDIA_ENDED = 8

    videoPlayer = CreateObject("roVideoPlayer")

   ' The messageport receives interrupts from linked objects and will be used to launch eventhandlers in the main loop below.
    port = CreateObject("roMessagePort")
    videoPlayer.SetPort(port)
    server.setport(port)
    
    ' Convert the playlist.xml into a roAssociativeArray
    xml = CreateObject("roXMLElement")
    if not xml.parseFile("/playlist.xml") then 
        info("not able to parse general.xml. script stopped. verify or reset configuration.")
        ScreenMessage("not able to parse general.xml. script stopped. verify or reset configuration.", 1000)
        ' TODO: stop might not work if not in debug mode?
        stop
    end if

    files = xml.task ' returns a roXMLList
    ' TODO: stop might not work if not in debug mode?    
    if files.count() = 0 then stop ' no files defined

    ' Where the player will look for media files
    mediaFolder = settings.mediaFolder.getText()

    ' Set audio volume and activate analog AND hdmi audio output 
    videoPlayer.setVolume(int(val(settings.volume.getText())))
    videoPlayer.SetAudioOutput(4)

    ' Always paly the first file of the playlist before entering the main loop, as the main loop 
    ' mainly will be triggered by mediea_ended events.
    files.reset() ' make sure the files iterator is set to the first element
    videoPlayer.StopClear() ' clear screen, as next file could be a audio file only, or a message must be displayed
    nextFile = getNextPlayable(videoPlayer, files, mediafolder)
    videoPlayer.playFile(nextFile)
    info("playing " + nextFile)
    
    '------ MAIN LOOP ------
    while true
        ' Wait for the next event. The occuring event will be stored in msg.
        msg = wait(0, port)
        ' roVieoEvent can signal various events that a videoPlayer triggers. Handle the MEDIA_ENDED event here.
        if type(msg) = "roVideoEvent" and msg.GetInt() = MEDIA_ENDED then 
            videoPlayer.StopClear() ' clear screen, as next file could be a audio file only, or a message must be displayed
            nextFile = getNextPlayable(videoPlayer, files, mediafolder)
            videoPlayer.playFile(nextFile)
            info("playing " + nextFile)
        ' roTCPConnectEvent signals, that a TCP connection request arrived at server object
        else if type(msg) = "roTCPConnectEvent" then
            handleTCPConnectEvent(msg, port, connections)
        ' roStremLineEvent signals, that a open connection recieved a sting, terminated with a LF (0x0A)
        else if type(msg) = "roStreamLineEvent" then 
            handleStreamLineEvent(msg)
        ' roStreamEndEvent signals, that a connection has been closed by a client.
        else if type(msg) = "roStreamEndEvent" then
            handleStreamEndEvent(msg)
        end if
    end while
End Sub

' This method finds the next playable file in the files list. If a file is not playable it will be skipped.
' 
' @param videoPlayer The videoPlayer that should play the file.
' @param files An roXMLList of the files defined in playlist.xml
' @param mediafolder String of the path of the forlder where the media files are stored
Function getNextPlayable(videoPlayer as Object, files as Object, mediafolder as String) As Object
    playableAsVideo = ""
    playableAsAudio = ""
    ' Only play playable files, skip others
    while playableAsVideo <> "playable" AND playableAsAudio <> "playable"
        ' Reset the iterator if he reached the end of the list
        if not files .isNext() then
            files.Reset()
        end if
        nextFile = files.Next()
        ' Find out if nextFile is playable as audio or video file
        playable = videoPlayer.GetFilePlayability(mediafolder + "/" + nextFile.GetText())
        playableAsVideo = playable.video
        playableAsAudio = playable.audio
        if playableAsVideo <> "playable" AND playableAsAudio <> "playable" then
            info("file " + mediafolder + "/" + nextFile.GetText() + " is not playable.")
            ScreenMessage("file " + mediafolder + "/" + nextFile.GetText() + " is not playable.", 3000)
        end if
    end while

    return mediafolder + "/" + nextFile.GetText()
end Function