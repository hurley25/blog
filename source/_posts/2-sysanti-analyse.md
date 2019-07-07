title: 对 SysAnti.exe 病毒的简单分析
date: 2012-11-21 15:02:00
tags:
- windows
- 病毒分析
categories: 病毒分析
toc: false
---

周一在2号实验楼323嵌入式实验室用U盘时发现有病毒，重启后发现刚启动时电脑就有病毒，看来还原卡没起作用。一时兴起打包了病毒文件回来研究下。

> 病毒文件名：SysAnti.exe
文件大小：52.5KB
MD5：4B160901566108C6F89F21444CE503E7

PEID查壳信息：

![](/images/2/1.png)

PEID显示是ASPack壳，这一款兼容性良好的老牌壳。不过估计用工具脱不了，OD载入时出错，看来经过特意加密防止反编译。我也懒得深入研究壳了，直接丢入虚拟机的XP，创建快照。打开Procmon和Total Uninstall监视，然后运行。

先分析Total Uninstall下直观的文件和注册表修改情况：

文件修改：

1.在C:\windows\Fonts目录下创建cjavv.fon和fprij.fon文件，从文件名上分析可能是随机文件名。

2.与实验室看到的不同，病毒在C:\windows\system32目录下创建了SysAnti.exe文件，而不是实验室的C:\Program Files\Common File目录。

![](/images/2/2.png)

3.修改了C:\windows\system32\drivers\etc目录下的hosts文件，将主流杀软网站指向本地127.0.0.1地址，以阻止用户访问。

<!-- more -->

![](/images/2/3.png)

4.在所有磁盘创建了SysAnti.exe和AutoRun.inf文件（老掉牙的自动运行传播方式）

![](/images/2/4.png)

其AutoRun.inf文件内容如下：

![](/images/2/5.png)

比较有意思的是这个病毒会检测并关闭打开的记事本，不让我看这个文件内容。不过写的不错，在鼠标右键伪造了“打开”和“资源管理器”选项以混淆用户。

文件修改暂时就这么多，不过Total Uninstall是静态监视器，呆会还要看Procmon动态记录的信息。

注册表修改：

[HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\policies\Explorer\Run，

“SysAnti”=”C:\windows\System32\SysAnti.exe”

这是建立自动运行。需要特别指出的是，这个路径下建立的自启动是不会显示在（msconfig）系统配置实用程序下的。

奇怪的是而在IceSword下也看不到，不过XueTr下可以看到启动项。

![](/images/2/6.png)

或者在组策略编辑器（gprdit.msc）的“登陆时运行这些程序”里也可以看到，也算是一种比较隐蔽的方式了。

然后是映像劫持，病毒在

HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\WindowsNT\CurrentVersion\Image File Execution Options 下建立了以下键值：

360hotfix.exe，360rpt.exe，360Safe.exe，360safebox.exe，360tray.exe，adam.exe，AgentSvr.exe，AntiArp.exe，AppSvc32.exe，arvmon.exe，AutoGuarder.exe，autoruns.exe，avgrssvc.exe，AvMonitor.exe，avp.com，avp.exe，CCenter.exe，ccSvcHst.exe，FileDsty.exe，findt2005.exe，FTCleanerShell.exe，HijackThis.exe，IceSword.exe，iparmo.exe，Iparmor.exe，IsHelp.exe，isPwdSvc.exe，kabaload.exe，KaScrScn.SCR，KASMain.exe，KASTask.exe，KAV32.exe，KAVDX.exe，KAVPFW.exe，KAVSetup.exe，KAVStart.exe，killhidepid.exe，KISLnchr.exe，KMailMon.exe，KMFilter.exe，KPFW32.exe，KPFW32X.exe，KPFWSvc.exe，KRepair.COM，KsLoader.exe，KVCenter.kxp，KvDetect.exe，kvfw.exe，KvfwMcl.exe，KVMonXP.kxp，KVMonXP_1.kxp，kvol.exe，kvolself.exe，KvReport.kxp，KVScan.kxp，KVSrvXP.exe，KVStub.kxp，kvupload.exe，kvwsc.exe，KvXP.kxp，KvXP_1.kxp，KWatch.exe，KWatch9x.exe，KWatchX.exe，LiveUpdate360.exe，loaddll.exe，MagicSet.exe，mcconsol.exe，mmqczj.exe，mmsk.exe，NAVSetup.exe，nod32krn.exe，nod32kui.exe，PFW.exe，PFWLiveUpdate.exe，QHSET.exe，Ras.exe，Rav.exe，RavCopy.exe，RavMon.exe，RavMonD.exe，RavStore.exe，RavStub.exe，ravt08.exe，RavTask.exe，RegClean.exe，RegEx.exe，rfwcfg.exe，RfwMain.exe，rfwolusr.exe，rfwProxy.exe，rfwsrv.exe，RsAgent.exe，Rsaupd.exe，RsMain.exe，rsnetsvr.exe，RSTray.exe，runiep.exe，safebank.exe，safeboxTray.exe，safelive.exe，scan32.exe，ScanFrm.exe，shcfg32.exe，smartassistant.exe，SmartUp.exe，SREng.exe，SREngPS.exe，symlcsvc.exe，syscheck.exe，Syscheck2.exe，SysSafe.exe，ToolsUp.exe，TrojanDetector.exe，Trojanwall.exe，TrojDie.kxp，UIHost.exe，UmxAgent.exe，UmxAttachment.exe，UmxCfg.exe，UmxFwHlp.exe，UmxPol.exe，UpLive.exe，WoptiClean.exe，zxsweep.exe

看来作者真费了一番苦心啊，收集了所有主流杀软和主流检测工具的文件名啊。不过映像劫持也很好破解，把打不开的杀软重命名就好了。

注册表修改基本就是这些，不过Total Uninstall只是简单的运行前后对比而已。

下来再看看Procmon的日志吧。

![](/images/2/7.png)

果然和Total Uninstall就不一样了，首先可以看到病毒加载了C:\windows\system32\ntdll.dll，这是NT系统的一个重要模块。顺带说一句，“臭名昭著”的strcpy就是在这里定义的….

在我截图的过程中发现所有带有SysAnti字样和带有Auorun字样的窗口都会被强制关闭，另外含有主流杀软名字的窗口也会被强制关闭。所以中毒电脑会被阻止通过搜索引擎查找相关资料。而新加入的可移动磁盘也会被建立SysAnti.exe和AutoRun.inf文件，以通过U盘等传播。不过没有发现病毒开启的端口，暂时看来不是木马什么的。

继续看日志，SysAnti.exe接着查询了映像劫持中有没有自己，发现没有后加载 C:\windows\system32\kernel32.dll，user32.dll等等诸多的dll运行库。运行rundll32.exe等等…..咦，TCP连接202.171.253.108，开始网络操作了，因为是虚拟机，我也没有安装任何的第三方防火墙，而windows自带的可以直接忽略….所以也没有发现连接对象。Procmon的记录很琐碎，大致就是这些，主要还是对注册表的一些操作，涉及到驱动什么的。

简单分析就到这里吧，下面检测下动态状况。

打开IceSword，额…那个名为IceSword的文件夹被瞬间关闭， IceSword也打不开…哦，对了，映像劫持。给IceSword改名后顺利打开并且正常运行了。奇怪，在进程中并未发现可疑的，难道是注入到某个系统进程了？或者是服务级别的？更有甚者，ring0级别把自己隐藏了？

先奔着最坏的可能去，嗯….内核模块没发现异常，服务和设备也没有增加。看来可以初步锁定为进程插入型了，至于这个到底是病毒还是木马现在还不好说。

虚拟机运行的XP本来就很干净，简单看了下进程，怀疑对象锁定在了explorer.exe和svchost.exe上。打开模块信息…..太多了，加载的模块都有好几十。为了检测起来容易些，重启虚拟机进入安全模式吧。在实验室我已经确认了病毒竟然能顺利运行在安全模式下。

不对….无法进入安全模式了….这个文件是我在实验室直接打包带回来的样品啊…目前搞不清楚状况了。

没办法，直接正常启动吧，先不修复安全模式了。运行Procmon，监视所有线程操作，嘿嘿，果然发现了幕后黑手svchost.exe，PID为704。咦，这个svchost.exe竟然是以administrator运行的，看来自己是大意了，连这么明显的破绽都没看到啊。

![](/images/2/8.png)

看来病毒是注入到svchost.exe进程里了，果断用IceSword查找svchost.exe的模块，比对后果然发现了问题。

![](/images/2/9.png)

先试试直接结束PID为704的svchost.exe吧，嗯…可以结束，看来不是双进程保护的。删除了C盘下的SysAnti.exe和AutoRun.inf文件，也没有被重建了。

清除所有病毒文件和注册表项目后重启，再没有发现病毒痕迹。

P.S.监视了这个病毒很长一段时间，日志里没有发现它对其余文件的操作和键盘记录之类，也不知道是不是需要某些特定情景的触发。总之，手工清除并不复杂...
