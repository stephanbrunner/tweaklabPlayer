Sub playlistMain(settings as Object, server as Object, connections as Object) 
    MEDIA_ENDED = 8

    videoPlayer = CreateObject("roVideoPlayer")
    port = CreateObject("roMessagePort")
    videoPlayer.SetPort(port)
    server.setport(port)
    
    xml = CreateObject("roXMLElement")
    if not xml.parseFile("/playlist.xml") then 
        info("not able to parse general.xml. script stopped. verify or reset configuration.")
        ScreenMessage("not able to parse general.xml. script stopped. verify or reset configuration.", 1000)
        stop
    end if

    files = xml.task
    if files.count() = 0 then stop

    mediaFolder = settings.mediaFolder.getText()

    ' set audio volume and activate analog AND hdmi audio output 
    videoPlayer.setVolume(int(val(settings.volume.getText())))
    videoPlayer.SetAudioOutput(4)

    '------ MAIN LOOP ------
    files.reset()
    videoPlayer.StopClear() ' clear screen, as next file could be a audio file only, or a message must be displayed
    nextFile = getNextPlayable(videoPlayer, files, mediafolder)
    videoPlayer.playFile(nextFile)
    info("playing " + nextFile)
    while true
        msg = wait(0, port)
        if type(msg) = "roVideoEvent" and msg.GetInt() = MEDIA_ENDED then 
            videoPlayer.StopClear() ' clear screen, as next file could be a audio file only, or a message must be displayed
            nextFile = getNextPlayable(videoPlayer, files, mediafolder)
            videoPlayer.playFile(nextFile)
            info("playing " + nextFile)
        else if type(msg) = "roTCPConnectEvent" then
            handleTCPConnectEvent(msg, port, connections)
        else if type(msg) = "roStreamLineEvent" then 
            handleStreamLineEvent(msg)
        else if type(msg) = "roStreamEndEvent" then
            handleStreamEndEvent(msg)
       end if
    end while
End Sub

Function getNextPlayable(videoPlayer as Object, files as Object, mediafolder as String) As Object
    playableAsVideo = ""
    playableAsAudio = ""
    ' only play playable files, skip others
    while playableAsVideo <> "playable" AND playableAsAudio <> "playable"
        ' reset the iterator if he reached the end
        if not files.isNext() then
            files.Reset()
        end if
        nextFile = files.Next()
        ' make sure the file is playable as a video file
        playable = videoPlayer.GetFilePlayability(mediafolder + "/" + nextFile.GetText())
        playableAsVideo = playable.video
        playableAsAudio = playable.audio
        if playableAsVideo <> "playable" AND playableAsAudio <> "playable" then
            info("file " + mediafolder + "/" + nextFile.GetText() + " is not playable.")
            ScreenMessage("file " + mediafolder + "/" + nextFile.GetText() + " is not playable.", 2000)
        end if
    end while

    return mediafolder + "/" + nextFile.GetText()
end Function