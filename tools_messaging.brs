sub ScreenMessage(message as String, duration as Integer)
    videoMode = CreateObject("roVideoMode")
    resX = videoMode.GetResX()
    resY = videoMode.GetResY()
    r=CreateObject("roRectangle",0,resY/2-resY/64,resX,resY/32)
    twParams = CreateObject("roAssociativeArray")
    twParams.LineCount = 1
    twParams.TextMode = 2
    twParams.Rotation = 0
    twParams.Alignment = 1
    tw=CreateObject("roTextWidget",r,1,2,twParams)
    tw.PushString(message)
    tw.Show()
    ' TODO: this is a bad solution, as event handler can't handle events while sleep is waiting.
    Sleep(duration)
end sub

sub info(message As String) 
    print message
    m.sysLog.SendLine("From Script: " + message)
end sub

function ShowSimpelHeader() as Object
    border = 20
    videoMode = CreateObject("roVideoMode")
    resX = videoMode.GetResX() - 2 * border
    resY = videoMode.GetResY() - 2 * border
    r=CreateObject("roRectangle", border, border, resX, resY)
    twParams = CreateObject("roAssociativeArray")
    twParams.LineCount = 30
    twParams.TextMode = 1
    twParams.Rotation = 0
    twParams.Alignment = 1
    tw=CreateObject("roTextWidget", r, twParams.LineCount, twParams.TextMode, twParams)
    content = CreateObject("roString")

    settings = CreateObject("roXMLElement")
    settings.parseFile("/settings.xml")

    app("", content)
    app("", content)
    app("", content)
    app("", content)
    app("", content)
    ' Title and script version
    app("TWEAKLAB Custom BrightScript Version " + settings.scriptVersion.getText(), content)
    app("in " + settings.mode.getText() + "-mode", content)
    app("", content)
    app("", content)
    app("... starting up ...", content)

    tw.PushString(content)
    tw.Show()

    return tw
end function

function ShowDeviceInfos() as Object
    border = 20
    videoMode = CreateObject("roVideoMode")
    resX = videoMode.GetResX() - 2 * border
    resY = videoMode.GetResY() - 2 * border
    r=CreateObject("roRectangle", border, border, resX, resY)
    twParams = CreateObject("roAssociativeArray")
    twParams.LineCount = 30
    twParams.TextMode = 1
    twParams.Rotation = 0
    twParams.Alignment = 1
    tw=CreateObject("roTextWidget", r, twParams.LineCount, twParams.TextMode, twParams)
    content = CreateObject("roString")

    settings = CreateObject("roXMLElement")
    settings.parseFile("/settings.xml")

    app("", content)
    app("", content)
    app("", content)
    app("", content)
    app("", content)
    ' Title and script version
    app("TWEAKLAB Custom BrightScript Version " + settings.scriptVersion.getText(), content)
    app("in " + settings.mode.getText() + "-mode", content)
    app("", content)
    app("", content)

    ' copy network configurations to content
    net = CreateObject("roNetworkConfiguration", 0)
    conf = net.GetCurrentConfig()
    app("Name: " + conf.hostname, content)
    if conf.dhcp then
        app("DHCP: enabled", content)
    else 
        app("DHCP: disabled", content)
    end if
    app("ip address: " + conf.ip4_address, content)
    app("netmask: " + conf.ip4_netmask, content)
    app("gateway: " + conf.ip4_gateway, content)
    netDiacnostics = net.TestInterface()
    if netDiacnostics.ok then
        app("ethernet: ok", content)
    else 
        app("ethernets first problem: " + netDiacnostics.diagnosis, content)
    end if
    app("MAC address: " + conf.ethernet_mac, content)

    ' video resoultion
    videoMode = CreateObject("roVideoMode")
    app("Video Resolution: " + videoMode.GetMode(), content)

    ' settings vom settings.xml
    app("Volume: " + settings.volume.GetText(), content)

    ' copy DeviceInfo to content'
    deviceInfo = CreateObject("roDeviceInfo")
    app("Model: " + deviceInfo.GetModel(), content)
    app("Firmware: " + deviceInfo.GetVersion(), content)
    app("Boot Firmware: " +  deviceInfo.GetBootVersion(), content)

    tw.PushString(content)
    tw.Show()

    return tw
end function

sub app(line as String, container as String)
    container.AppendString(line + chr(10), line.len() + 1)
end sub