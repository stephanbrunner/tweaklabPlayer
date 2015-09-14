' Iterates through the registry and clears all entries.
Sub ClearRegistry()
    ' The registry has two levels. The sections, and the keys. Iterate through each key in each section.
    reg = CreateObject("roRegistry")
    for each sectionName in reg.GetSectionList()
        section = CreateObject("roRegistrySection", sectionName)
        for each key in section.getKeyList()
            section.Delete(key)
            section.flush() ' TODO: might not be nessecary?
        end for
        reg.Delete(sectionName)
        reg.flush()
    end for
End Sub

' @param settings The settings.xml converted into a roXMLElement.
Sub UpdateNetworkSettings(settings As Object)
    netConf = CreateObject("roNetworkConfiguration", 0)
    current = netConf.GetCurrentConfig()
    if current.dhcp = false and settings.dhcp.getText() = "true"
        info("changing dhcp to enabled")
        ScreenMessage("changing dhcp to enabled", 3000)
        netConf.setDHCP()
    else
        if current.ip4_address <> settings.ip.getText() then
            info("changing ip from " + current.ip4_address + " to " + settings.ip.getText())
            ScreenMessage("changing ip from " + current.ip4_address + " to " + settings.ip.getText(), 3000)
            netConf.setIP4Address(settings.ip.getText())
        end if
        if current.ip4_netmask <> settings.netmask.getText() then
            info("changing netmaske from " + current.ip4_netmask + " to " + settings.netmask.getText())
            ScreenMessage("changing netmaske from " + current.ip4_netmask + " to " + settings.netmask.getText(), 3000)
            netConf.setIP4Netmask(settings.netmask.getText())
        end if
        if current.ip4_gateway <> settings.gateway.getText() then
            info("changing gateway from " + current.ip4_gateway + " to " + settings.gateway.getText())
            ScreenMessage("changing gateway from " + current.ip4_gateway + " to " + settings.gateway.getText(), 3000)
            netConf.setIP4Gateway(settings.gateway.getText())
        end if
    end if
    if netConf.getHostName() <> settings.name.getText() then
        info("changing name from " + netConf.getHostName() + " to " + settings.name.getText())
        ScreenMessage("changing name from " + netConf.getHostName() + " to " + settings.name.getText(), 3000)
        netConf.setHostName(settings.name.getText())
    end if
    ' Password must be set every time, as it can't be read a compared.
    netConf.SetLoginPassword(settings.ssh_password.getText())
    netConf.apply()
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

' @param tweaklabRegistry The tweaklab Registry.
Function UpdateDisplaySettings(tweaklabRegistry as Object) as Object
    changed = false

    ' Quit script if display.xml is not available. 
    displaySettings = CreateObject("roXMLElement")
    if not displaySettings.parseFile("/display.xml") then
        info("not able to parse display.xml. stopping script. verify or reset configuration.")
        ScreenMessage("not able to parse display.xml. stopping script. verify or reset configuration.", 1000)
        ' TODO: stop might not work if not in debug mode?
        stop
    end if

    videoMode = CreateObject("roVideoMode")

    ' If display.xml contented a resolution that was not playable at last boot. To communicate that issue we
    ' need to use the screen, but as it would be set to an invalid resulotion, we first have to put the 
    ' videoMode and the display.xml to "auto", rebbot the system, and show the following message.
    if tweaklabRegistry.read("resolutionValidity") = "false" then
        info("Resolution was not valid at last boot and was set to auto if you didn't change it.")
        ScreenMessage("Resolution was not valid at last boot and was set to auto if you didn't change it.", 4000)
        tweaklabRegistry.write("resolutionValidity", "true")
    end if

    ' Settings changed to autoformat?
    if displaySettings.auto.getText() = "true" and videoMode.getModeForNextBoot() <> "auto"
        videoMode.SetModeForNextBoot("auto")
        info("changing display settings to autoformat.")
        info("rebooting to make display settings taking effect. please reconnect after reboot!")
        ScreenMessage("changing display settings to autoformat. rebooting...", 3000)
        tweaklabRegistry.write("resolutionValidity", "true")
        changed = true
    else
        ' Collect settings
        width = displaySettings.width.getText()
        height = displaySettings.height.getText()
        freq = displaySettings.freq.getText()
        if displaySettings.interlaced.getText() = "true" then
            interlaced = "i"
        else 
            interlaced = "p"
        end if 

        ' Compare settings
        if videoMode.getMode() <> (width + "x" + height + "x" + freq + interlaced) then 
            if videoMode.SetModeForNextBoot(width + "x" + height + "x" + freq + interlaced) then
                info("changing display settings from " + videoMode.getMode() + " to " + width + "x" + height + "x" + freq + interlaced)
                info("rebooting to make display settings taking effect. please reconnect after reboot!")
                ScreenMessage("changing display settings from " + videoMode.getMode() + " to " + width + "x" + height + "x" + freq + interlaced + ". rebooting...", 3000)
                tweaklabRegistry.write("resolutionValidity", "true")
            else
                videoMode.SetModeForNextBoot("auto") ' make sure error message can be displaied after next boot.    
                tweaklabRegistry.write("resolutionValidity", "false")
                ' set dispay.xml to auto to avoid boot-loop
                ' TODO unfortuantly this kills the formating and makes the xml almost anreadable
                displaySettings.auto.simplify().setbody("true")
                out = CreateObject("roByteArray")
                out.FromASCIIString(displaySettings.GenXML(true))
                out.WriteFile("display.xml")
            end if
            changed = true
        end if
    end if

    ' this is needed, to show text messages on the screen after a video was played. Otherwise messages would be overlaied.
    EnableZoneSupport(true)
    videoMode.SetGraphicsZOrder("front")

    return changed
end Function

' Deletes the content of the media folder.
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

' Deletes all files on the SD-Card
sub clearSD()
    for each e in ListDir("/")
        if not DeleteFile(e) then
            if not DeleteDirectory(e) then
                info(e + " is not deletable")
            end if
        end if
    end for
end sub