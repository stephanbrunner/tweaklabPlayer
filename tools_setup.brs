Sub ClearRegistry()
    reg = CreateObject("roRegistry")
    for each sectionName in reg.GetSectionList()
        section = CreateObject("roRegistrySection", sectionName)
        for each key in section.getKeyList()
            section.Delete(key)
            section.flush()
        end for
        reg.Delete(sectionName)
        reg.flush()
    end for
End Sub

Sub UpdateNetworkSettings(settings As Object)
    nc = CreateObject("roNetworkConfiguration", 0)
    current = nc.GetCurrentConfig()
    if current.dhcp = false and settings.dhcp.getText() = "true"
        info("changing dhcp to enabled")
        ScreenMessage("changing dhcp to enabled", 3000)
        nc.setDHCP()
    else
        if current.ip4_address <> settings.ip.getText() then
            info("changing ip from " + current.ip4_address + " to " + settings.ip.getText())
            ScreenMessage("changing ip from " + current.ip4_address + " to " + settings.ip.getText(), 3000)
            nc.setIP4Address(settings.ip.getText())
        end if
        if current.ip4_netmask <> settings.netmask.getText() then
            info("changing netmaske from " + current.ip4_netmask + " to " + settings.netmask.getText())
            ScreenMessage("changing netmaske from " + current.ip4_netmask + " to " + settings.netmask.getText(), 3000)
            nc.setIP4Netmask(settings.netmask.getText())
        end if
        if current.ip4_gateway <> settings.gateway.getText() then
            info("changing gateway from " + current.ip4_gateway + " to " + settings.gateway.getText())
            ScreenMessage("changing gateway from " + current.ip4_gateway + " to " + settings.gateway.getText(), 3000)
            nc.setIP4Gateway(settings.gateway.getText())
        end if
    end if
    if nc.getHostName() <> settings.name.getText() then
        info("changing name from " + nc.getHostName() + " to " + settings.name.getText())
        ScreenMessage("changing name from " + nc.getHostName() + " to " + settings.name.getText(), 3000)
        nc.setHostName(settings.name.getText())
    end if
    nc.SetLoginPassword(settings.ssh_password.getText())
    nc.apply()
End Sub

Sub SetAllLoggingEnabled()
    section = CreateObject("roRegistrySection", "networking")
    section.Write("ple", "yes") 'playbackLoggingEnabled'
    section.Write("ele", "yes") 'eventLoggingEnabled'
    section.Write("sle", "yes") 'stateLoggingEnabled'
    section.Write("dle", "yes") 'diagnosticLoggingEnabled'
    section.Write("uab", "no")  'uploadLogFilesAtBoot'
    section.Write("uat", "no")  'uploadLogFilesAtSpecificTime'
    section.Write("ut", "0")    'uploadLogFilesTime'
End Sub

Function UpdateDisplaySettings() as Object
    changed = false

    displaySettings = CreateObject("roXMLElement")
    if not displaySettings.parseFile("/display.xml") then
        info("not able to parse display.xml. stopping script. verify or reset configuration.")
        ScreenMessage("not able to parse display.xml. stopping script. verify or reset configuration.", 1000)
        stop
    end if

    videoMode = CreateObject("roVideoMode")

    'changed to autoformat?
    if displaySettings.auto.getText() = "true" and videoMode.getModeForNextBoot() <> "auto"
        videoMode.SetModeForNextBoot("auto")
        info("changing display settings to autoformat.")
        info("rebooting to make display settings taking effect. please reconnect after reboot!")
        ScreenMessage("changing display settings to autoformat. rebooting...", 3000)
        changed = true
    end if

    'autoformat is disabled and format was changed?
    width = displaySettings.width.getText()
    height = displaySettings.height.getText()
    freq = displaySettings.freq.getText()
    if displaySettings.interlaced.getText() = "true" then
        interlaced = "i"
    else 
        interlaced = "p"
    end if 

    if displaySettings.auto.getText() = "false" and videoMode.getMode() <> (width + "x" + height + "x" + freq + interlaced) then 
        videoMode.SetModeForNextBoot(width + "x" + height + "x" + freq + interlaced)
        info("changing display settings from " + videoMode.getMode() + " to " + width + "x" + height + "x" + freq + interlaced)
        info("rebooting to make display settings taking effect. please reconnect after reboot!")
        ScreenMessage("changing display settings from " + videoMode.getMode() + " to " + width + "x" + height + "x" + freq + interlaced + ". rebooting...", 3000)
        changed = true
    end if

    ' this is needed, to show text messages on the screen after a video was played
    EnableZoneSupport(true)
    videoMode.SetGraphicsZOrder("front")

    return changed
end Function

sub resetFileStructure()
    ' set mediaFolder from settings.xml
    settings = CreateObject("roXMLElement")
    if not settings.parseFile("/settings.xml") then
        print "not able to parse /settings.xml"
        stop
    end if
    mediaFolder = settings.mediaFolder.getText()

    DeleteDirectory("/" + mediaFolder)
    CreateDirectory("/" + mediaFolder)
end sub