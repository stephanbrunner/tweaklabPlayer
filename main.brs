Library "gpio.brs"
Library "playlist.brs"
Library "tools_setup.brs"
Library "tools_messaging.brs"
Library "tools_tcp.brs"

' Tweaklab Custom BrightScript for BrightSign Players
' ---------------------------------------------------

' This Script is responsible to bring a Bright Sign Player in a valid state to run main scripts. In order
' to do that, it parses the settings.xml and display.xml and adapts registry settings. 

' Version 1.0
' Stephan Brunner
' Tweaklab

sub tweaklabPlayer()
    screenContent = ShowSimpelHeader()

    ' enable debugging
    m.sysLog = createObject("roSystemLog")
    MAX_CONNECTIONS = 10

    ' generate a AssociativeArray (aka Hashmap) out of the settings.xml settings
    settings = CreateObject("roXMLElement")
    if not settings.parseFile("/settings.xml") then
        info("not able to parse settings.xml script stopped. verify or reset configuration.")
        ScreenMessage("not able to parse settings.xml. script stopped. verify or reset configuration.", 1000)
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
        ScreenMessage("FIRMWAREVERSION NOT SUPPORTED. ISSUES MAY OCCURE.", 3000)
    end if
    minimumBootFirmwareVersionAsNumber = 4*65536 + 9*256 + 29
    if deviceInfo.GetBootVersionNumber() < minimumBootFirmwareVersionAsNumber then
        info("BOOT-FIRMWAREVERSION NOT SUPPORTED. ISSUES MAY OCCURE.")
        info("")
        ScreenMessage("BOOT-FIRMWAREVERSION NOT SUPPORTED. ISSUES MAY OCCURE.", 3000)
    end if

    ' a reboot might be necessarry depending on changes
    reboot = false

    ' if a initialisation is wanted, all registry entries are cleared and reset to a appropriate state.
    if settings.initialize.getText() = "true" 
        info("setting player back to initial settings. rebooting...")
        ScreenMessage("setting player back to initial settings. rebooting...", 3000)

        ' factory reset
        ' TODO: CreateObject("roDeviceCustomization").FactoryReset("confirm") einbauen. hat nachteile da der Befehl automatisch rebootet, also der dhcp nicht mehr deaktiviert werden kann. 
        ClearRegistry() ' method from SetupTools.brs

        SetAllLoggingEnabled() ' method from SetupTools.brs'

        ' enable webserver and diacnostic webserver
        networkRegistry = createObject("roRegistrySection", "networking")
        networkRegistry.write("http_server", "80")

        ' enable ssh
        networkRegistry.write("ssh","22")

        ' set initialize back to false in settings.xml (to avoid reboot loop)
        ' TODO unfortuantly this kills the formating and makes the xml almost anreadable
        settings.initialize.simplify().setbody("false")
        out = CreateObject("roByteArray")
        out.FromASCIIString(settings.GenXML(true))
        out.WriteFile("settings.xml")

        reboot = true
    end if

    ' if display.xml changed, update settings. needs a reboot
    if UpdateDisplaySettings() = true then ' method from SetupTools.brs
        reboot = true
    end if

    ' if network settings changed, update settings, and always reset password. 
    '
    ' Doesn't need a reboot but must be before the rebootSystem() to have the right network settings set 
    ' after the reboot. They might be used.
    UpdateNetworkSettings(settings) ' method from SetupTools.brs

    if (reboot) then
        rebootSystem()
    end if

    ' setup tcp server
    server = createObject("roTCPServer")
    connections = createObject("roArray", MAX_CONNECTIONS, false)
    server.bindToPort(int(val(settings.tcp_port.getText())))

    for i = 1 to MAX_CONNECTIONS step +1
        connections.push(newConnection())
    end for

    ' activate bonjour advertisement
    props = { name: settings.name.getText(), type: "_tl._tcp", port: int(val(settings.tcp_port.getText())), _serial: deviceInfo.GetDeviceUniqueId() }
    advert = CreateObject("roNetworkAdvertisement", props)

    screenContent = ShowDeviceInfos()
    sleep(10000) ' show Diacnostic screen for ... miniseconds
    screenContent = invalid

    ' start main script
    if settings.mode.getText() = "gpio" then
        gpioMain(settings, server, connections)
    else if settings.mode.getText() = "playlist" then
        playlistMain(settings, server, connections)
    end if
end sub