sub gpioMain(settings as Object, server as Object, connections as Object)
    ' used states for roVideoEvent and playerState
    m.PLAYING = 3
    m.MEDIA_ENDED = 8
    m.READY = 10

    videoPlayer = CreateObject("roVideoPlayer")
    playerState = m.READY
    
    gpio = CreateObject("roControlPort", "BrightSign")
    ' Buttons
    gpio.EnableInput(0)
    gpio.EnableInput(1)
    gpio.EnableInput(2)
    gpio.EnableInput(3)
    ' LED's
    gpio.EnableOutput(4)
    gpio.EnableOutput(5)
    gpio.EnableOutput(6)
    gpio.EnableOutput(7)
    
    port = CreateObject("roMessagePort")
    gpio.SetPort(port)
    videoPlayer.SetPort(port)
    server.setport(port)

    mediaFolder = settings.mediaFolder.getText()

    ' set audio volume and activate analog AND hdmi audio output 
    videoPlayer.setVolume(int(val(settings.volume.getText())))
    videoPlayer.SetAudioOutput(4)

    gpioXml = CreateObject("roXMLElement")
    if not gpioXml.parseFile("/gpio.xml") then
        info("not able to parse gpio.xml. script stopped. verify or reset configuration.")
        ScreenMessage("not able to parse gpio.xml. script stopped. verify or reset configuration.", 1000)
        stop
    end if

    ' set retriggerEnabled from gpio.xml
    if (gpioXml.retriggerEnabled.count() = 0) then 
        retriggerEnabled = true 'default
    else if (gpioXml.retriggerEnabled.getText() = "true") then 
        retriggerEnabled = true
    else 
        retriggerEnabled = false
    end if

    ' set retriggerDelay from gpio.xml
    if (gpioXml.retriggerDelay.count() = 0) then 
        retriggerDelay = 0 'default
    else if retriggerEnabled then 
        retriggerDelay = val(gpioXml.retriggerDelay.getText())
    else 
        retriggerDelay = 0
    end if

    ' always start with the loop, if loop is defined
    if gpioXml.loop.count() > 0 then 
        playLoopFile(mediafolder + "/" + gpioXml.loop.getText(), videoPlayer, gpio, playerState)
    end if

    retriggerTimer = CreateObject("roTimespan")
    retriggerTimer.Mark()

    ' ---- MAIN LOOP ----
    while true
        msg = wait(0, port)
        if type(msg) = "roControlDown" and ((not retriggerEnabled and playerState =  READY) or (retriggerEnabled and retriggerTimer.totalMilliseconds() > retriggerDelay)) then
            if msg.getInt() = 0 and gpioXml.gpio0.count() > 0 then
                playGPIOFile(mediafolder + "/" + gpioXml.gpio0.getText(), videoPlayer, gpio, playerState, retriggerTimer)
            else if msg.getInt() = 1 and gpioXml.gpio1.count() > 0 then 
                playGPIOFile(mediafolder + "/" + gpioXml.gpio1.getText(), videoPlayer, gpio, playerState, retriggerTimer)
            else if msg.getInt() = 2 and gpioXml.gpio2.count() > 0 then 
                playGPIOFile(mediafolder + "/" + gpioXml.gpio2.getText(), videoPlayer, gpio, playerState, retriggerTimer)
            else if msg.getInt() = 3 and gpioXml.gpio3.count() > 0 then 
                playGPIOFile(mediafolder + "/" + gpioXml.gpio3.getText(), videoPlayer, gpio, playerState, retriggerTimer)
            end if
        else if type(msg) = "roVideoEvent" and msg.GetInt() = m.MEDIA_ENDED then
            if gpioXml.loop.count() > 0 then 
                playLoopFile(mediafolder + "/" + gpioXml.loop.getText(), videoPlayer, gpio, playerState)
            else
                print "file ended, no loop file defined"
            end if
            gpio.SetWholeState(0)
            playerState = m.READY
        else if type(msg) = "roTCPConnectEvent" then
            handleTCPConnectEvent(msg, port, connections)
        else if type(msg) = "roStreamLineEvent" then 
            handleStreamLineEvent(msg)
        else if type(msg) = "roStreamEndEvent" then
            handleStreamEndEvent(msg)
        end if
    end while 
end sub

sub playGPIOFile(file as String, videoPlayer as Object, gpio as Object, playerState as Object, retriggerTimer as Object)
    ' in any case, clear the screen and reset all highlightet buttons
    videoPlayer.StopClear() ' screen must be cleared, as next file could be an audio file only
    gpio.SetWholeState(0)

    playable = videoPlayer.GetFilePlayability(file)
    playableAsVideo = (playable.video = "playable")
    playableAsAudio = (playable.audio = "playable")
    if playableAsAudio OR playableAsVideo
        videoPlayer.playFile(file)
        gpio.SetOutputState(4, 1)
        playerState = m.PLAYING
        retriggerTimer.Mark()
        info("playing " + file)
    else
        info("not able to play " + file)
        ScreenMessage("not able to play " + file, 3000)
    end if
end sub

sub playLoopFile(file as String, videoPlayer as Object, gpio as Object, playerState as Object)
    playable = videoPlayer.GetFilePlayability(file)
    playableAsVideo = (playable.video = "playable")
    playableAsAudio = (playable.audio = "playable")
    if playableAsAudio OR playableAsVideo
        videoPlayer.StopClear() ' screen must be cleared, as next file could be an audio file only
        videoPlayer.playFile(file)
        info("playing the loop file " + file)
    else
        info("not able to play" + file)
        ScreenMessage("not able to play " + file, 3000) ' from MessageTools.brs
    end if
end sub
