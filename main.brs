Library "gpio.brs"
Library "playlist.brs"
Library "tools_setup.brs"
Library "tools_messaging.brs"
Library "tools_tcp.brs"

' Tweaklab Custom BrightScript for BrightSign Players
' ---------------------------------------------------
'
' This Script is responsible to bring a Bright Sign Player in a valid state and to run the script chosen with the <mode> setting. 
' In order to do that, it parses the settings.xml and display.xml, adapts registry settings and creates objects that are
' used by the scripts anyway.
'
' Version 1.0
' Stephan Brunner
' Tweaklab
' 11.09.2015

sub tweaklabPlayer()
    ' screenContent is used to store the displayed content while other jobs are done. Show simple header until device info is collected and shown at the end of the script.
    screenContent = ShowSimpelHeader()

    ' the syslog that will be used to log
    m.sysLog = createObject("roSystemLog")

    ' size of the connections pool
    MAX_CONNECTIONS = 10

    ' generate a AssociativeArray (aka Hashmap) out of the settings.xml. Quit script if not available
    settings = CreateObject("roXMLElement")
    if not settings.parseFile("/settings.xml") then
        info("not able to parse settings.xml script stopped. verify or reset configuration.")
        ScreenMessage("not able to parse settings.xml. script stopped. verify or reset configuration.", 1000) ' from tools_messaging.brs
        ' TODO: stop might not work if not in debug mode?
        stop
    end if

    info("------- TWEAKLAB Custom BrightScript Version " + settings.scriptVersion.getText() + " -------")
    info("")

    ' test firmware compatibility
    deviceInfo = createObject("roDeviceInfo")
    miniumFirmwareVersionAsNumber = 5*65536 + 1*256 + 54
    if deviceInfo.GetVersionNumber() < miniumFirmwareVersionAsNumber then
        info("FIRMWAREVERSION NOT SUPPORTED. ISSUES MAY OCCURE.")
        info("")
        ScreenMessage("FIRMWAREVERSION NOT SUPPORTED. ISSUES MAY OCCURE.", 3000) ' from tools_messaging.brs
    end if
    minimumBootFirmwareVersionAsNumber = 4*65536 + 9*256 + 29
    if deviceInfo.GetBootVersionNumber() < minimumBootFirmwareVersionAsNumber then
        info("BOOT-FIRMWAREVERSION NOT SUPPORTED. ISSUES MAY OCCURE.")
        info("")
        ScreenMessage("BOOT-FIRMWAREVERSION NOT SUPPORTED. ISSUES MAY OCCURE.", 3000) ' from tools_messaging.brs
    end if


    ' if a initialisation is wanted, all registry entries are cleared and reset to a appropriate state.
    if settings.initialize.getText() = "true" 
        ' set initialize back to false in settings.xml (to avoid reboot loop)
        ' TODO unfortuantly this kills the formating and makes the xml almost unreadable
        settings.initialize.simplify().setbody("false")
        out = CreateObject("roByteArray")
        out.FromASCIIString(settings.GenXML(true))
        out.WriteFile("settings.xml")

        info("setting player back to initial settings. rebooting...")
        ScreenMessage("setting player back to initial settings. rebooting...", 3000) ' from tools_messaging.brs

        ' TODO: from BrightScript Version 6, the following funkction will be supported. 
        ' CreateObject("roDeviceCustomization").FactoryReset("confirm")

        ' Clear Registry, this is almost as good as a factory reset, but doen't affect BOOT:, RTC and FLASH:
        ClearRegistry()
    end if

    ' a reboot might be necessarry depending on changes. In this case this variable can be set to true and the reboot 
    ' will be executed when all settings are up to date.
    reboot = false

    ' if registry is Empty, create and update necessary sections
    if createObject("roRegistry").GetSectionList().Count() = 0 then
        ' enable webserver and diacnostic webserver
        networkRegistry = createObject("roRegistrySection", "networking")
        networkRegistry.write("http_server", "80")

        ' enable ssh
        networkRegistry.write("ssh","22")
        
        SetAllLoggingEnabled() ' method from tools_setup.brs'

        reboot = true
    end if

    tweaklabRegistry = CreateObject("roRegistrySection", "tweaklab")
    ' If display.xml changed, update settings. needs a reboot
    if UpdateDisplaySettings(tweaklabRegistry) = true then ' method from tools_setup.brs
        reboot = true
    end if

    ' If network settings changed, update settings, and always update password. 
    '
    ' Doesn't need a reboot but must be before the rebootSystem() to have the right network settings set 
    ' after the reboot. They might be used. For examble if someone wants to connect via ssh.
    UpdateNetworkSettings(settings) ' method from tools_setup.brs

    if (reboot) then
        rebootSystem()
    end if

    ' setup tcp server
    server = createObject("roTCPServer")
    connections = createObject("roArray", MAX_CONNECTIONS, false)
    server.bindToPort(int(val(settings.tcp_port.getText())))

    ' Fill connections pool with roTCPStreams
    for i = 1 to MAX_CONNECTIONS step +1
        connections.push(newConnection()) ' newConnection() from tools_tcp.brs
    end for

    ' activate bonjour advertisement
    props = { name: settings.name.getText(), type: "_tl._tcp", port: int(val(settings.tcp_port.getText())), _serial: deviceInfo.GetDeviceUniqueId() }
    advert = CreateObject("roNetworkAdvertisement", props)

    ' shoe device info
    screenContent = ShowDeviceInfos() ' from tools_messaging.brs
    sleep(10000) ' show Diacnostic screen for ... miniseconds
    screenContent = invalid

    ' start script chosen with the <mode> setting
    if settings.mode.getText() = "gpio" then
        gpioMain(settings, server, connections)
    else if settings.mode.getText() = "playlist" then
        playlistMain(settings, server, connections)
    end if
end sub