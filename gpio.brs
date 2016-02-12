' 
' This script is used, when <mode>gpio</mode> is chosen in settings.xml. The player is then works as a gpio triggered
' player with 4 triggers maximum. Each gpio has an gpio output that is thought to be used to drive backlight LED's 
' of buttons. If the player is triggered, and a corresponding file difined in gpio.xml is actualy available and 
' playable, the corresponding LED will be lit, as long as the file is playing. 
' 
' Stephan Brunner
' Tweaklab
' Version 1.0
' 11.09.2015
' 
' @param settings The settings.xml converted to an Associative Array
' @param server An opened server object that will be used to comunicate with the client software
' @param connections A pool of 10 yet unused roTCPStream objects. 
sub gpioMain(settings as Object, server as Object, connections as Object)
    ' used states of roVideoEvent(predefined) and playerState(selfdefined)
    m.PLAYING = 3
    m.MEDIA_ENDED = 8
    m.READY = 10
    
    videoPlayer = CreateObject("roVideoPlayer")
    playerState = m.READY
    
    gpio = CreateObject("roControlPort", "BrightSign")
    ' Buttons
    gpio.EnableInput(0) ' trigggers the <gpio0> file in deifined in gpio.xml
    gpio.EnableInput(1) ' trigggers the <gpio1> file in deifined in gpio.xml
    gpio.EnableInput(2) ' trigggers the <gpio2> file in deifined in gpio.xml
    gpio.EnableInput(3) ' trigggers the <gpio3> file in deifined in gpio.xml
    ' LED's
    ' TODO: klären ob active low nich besser ist.
    gpio.EnableOutput(4) ' is high while the <gpio0> file in deifined in gpio.xml is playing
    gpio.EnableOutput(5) ' is high while the <gpio1> file in deifined in gpio.xml is playing
    gpio.EnableOutput(6) ' is high while the <gpio2> file in deifined in gpio.xml is playing
    gpio.EnableOutput(7) ' is high while the <gpio3> file in deifined in gpio.xml is playing
    
    ' The messageport receives interrupts from linked objects and will be used to launch eventhandlers in the main loop below.
    port = CreateObject("roMessagePort")
    gpio.SetPort(port)
    videoPlayer.SetPort(port)
    server.setport(port)

    ' Where the player will look for media files
    mediaFolder = settings.mediaFolder.getText()

    ' Set audio volume. Activate analog AND hdmi audio output
    videoPlayer.setVolume(int(val(settings.volume.getText())))
    videoPlayer.SetAudioOutput(4)

    ' convert the gpio.xml into a roAssociativeArray
    gpioSettings = CreateObject("roXMLElement")
    if not gpioSettings.parseFile("/gpio.xml") then
        info("not able to parse gpio.xml. script stopped. verify or reset configuration.")
        screenContent = ScreenMessage("not able to parse gpio.xml. script stopped. verify or reset configuration.", 1000)

        while true
        end while
    end if

    ' set retriggerEnabled from gpio.xml
    if (gpioSettings.retriggerEnabled.count() = 0) then 
        retriggerEnabled = true 'default
    else if (gpioSettings.retriggerEnabled.getText() = "true") then 
        retriggerEnabled = true
    else 
        retriggerEnabled = false
    end if

    ' set retriggerDelay from gpio.xml
    if (gpioSettings.retriggerDelay.count() = 0) then 
        retriggerDelay = 0 'default
    else if retriggerEnabled then 
        retriggerDelay = val(gpioSettings.retriggerDelay.getText())
    else 
        retriggerDelay = 0
    end if

    ' always start with the loop file, if loop is defined
    if gpioSettings.loop.count() > 0 then 
        playLoopFile(mediafolder + "/" + gpioSettings.loop.getText(), videoPlayer)
    end if

    ' The retrigger timing is realised with a timer that will be set with .mark() after each gpio trigger inpulse. 
    retriggerTimer = CreateObject("roTimespan")
    retriggerTimer.Mark()

    ' ---- MAIN LOOP ----
    while true
        ' Wait for the next event. The occuring event will be stored in msg.
        msg = wait(0, port)
        ' roControlDown signals, that a gpio pin was pulled down. Ignore event if player is not READY or if retriggerTimer didn't count up to retriggerDelay yet
        if type(msg) = "roControlDown" and ((not retriggerEnabled and playerState =  m.READY) or (retriggerEnabled and retriggerTimer.totalMilliseconds() > retriggerDelay)) then
            if msg.getInt() = 0 and gpioSettings.gpio0.count() > 0 then
                if playGPIOFile(mediafolder + "/" + gpioSettings.gpio0.getText(), videoPlayer, gpio) = true then
                    playerState = m.PLAYING
                    retriggerTimer.Mark()
                end if
            else if msg.getInt() = 1 and gpioSettings.gpio1.count() > 0 then 
                if playGPIOFile(mediafolder + "/" + gpioSettings.gpio1.getText(), videoPlayer, gpio) = true then
                    playerState = m.PLAYING
                    retriggerTimer.Mark()
                end if
            else if msg.getInt() = 2 and gpioSettings.gpio2.count() > 0 then 
                if playGPIOFile(mediafolder + "/" + gpioSettings.gpio2.getText(), videoPlayer, gpio) = true then
                    playerState = m.PLAYING
                    retriggerTimer.Mark()
                end if
            else if msg.getInt() = 3 and gpioSettings.gpio3.count() > 0 then 
                if playGPIOFile(mediafolder + "/" + gpioSettings.gpio3.getText(), videoPlayer, gpio) = true then
                    playerState = m.PLAYING
                    retriggerTimer.Mark()
                end if
            end if
        ' roVieoEvent can signal various events that a videoPlayer triggers. Handle the MEDIA_ENDED event here.
        else if type(msg) = "roVideoEvent" and msg.GetInt() = m.MEDIA_ENDED then
            if gpioSettings.loop.count() > 0 then 
                playLoopFile(mediafolder + "/" + gpioSettings.loop.getText(), videoPlayer)
            else
                videoPlayer.StopClear()
                print "file ended, no loop file defined"
            end if
            ' Reset all LED gpio pins
            gpio.SetWholeState(0)
            playerState = m.READY
        ' roTCPConnectEvent signals, that a TCP connection request arrived at server object
        else if type(msg) = "roTCPConnectEvent" then
            handleTCPConnectEvent(msg, port, connections) ' script frim tools_tcp.brs
        ' roStremLineEvent signals, that a open connection recieved a sting, terminated with a LF (0x0A)
        else if type(msg) = "roStreamLineEvent" then 
            handleStreamLineEvent(msg) ' script frim tools_tcp.brs
        ' roStreamEndEvent signals, that a connection has been closed by a client.
        else if type(msg) = "roStreamEndEvent" then
            handleStreamEndEvent(msg) ' script frim tools_tcp.brs
        end if
    end while 
end sub

' @param file The path of the file as a String.
' @param videoPlayer The videoPlayer that should play the file.
' @param gpio The gpio-port, configured as 4 inputs and 4 outputs.
Function playGPIOFile(file as String, videoPlayer as Object, gpio as Object) as Object
    ' screen must be cleared, as next file could be an audio file only
    videoPlayer.StopClear() 
    ' Reset all LED gpio pins
    gpio.SetWholeState(0)

    playable = videoPlayer.GetFilePlayability(file)
    playableAsVideo = (playable.video = "playable")
    playableAsAudio = (playable.audio = "playable")
    if playableAsAudio OR playableAsVideo
        videoPlayer.playFile(file)
        gpio.SetOutputState(4, 1)
        info("playing " + file)
    else
        info("not able to play " + file)
        ScreenMessage("not able to play " + file, 3000)
    end if
end Function

' @param file The path of the file as a String.
' @param videoPlayer The videoPlayer that should play the file.
sub playLoopFile(file as String, videoPlayer as Object)
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
