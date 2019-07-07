title: Emmet——快速的编写HTML和CSS代码
date: 2013-02-25 15:00:00
tags:
- 前端
- 基础知识
categories: 编程工具
toc: false
---

这学期被自愿的选择了《Web应用程序设计》这门课，还是自学课。好吧，反正基础的HTML和CSS迟早也是要学习的，就提前学吧。

按照我的性子，当学习新的语言以及语法规则的时候，我就又开始折腾编辑器的语法高亮和配置自动补全功能了。其实接触到新的语言时，我个人建议还是不要急着去寻找相关的IDE去使用，还是先用基本的文本编辑器写，尝试自己手工去构建。等到理解了之后再使用IDE提高编码效率也不晚。IDE的方便是建立在对很多细节的屏蔽之上的，这样对学习新的知识没有益处。没有手写HTML的经验，全靠IDE点点按钮，拖拖控件的设计人员在调试的时候就会是一场噩梦。

另外，个人吐槽下网上到处可见的什么“真正的高手写代码只用记事本”。你确定是notepad？没有++？好吧，个人感觉用记事本写代码如果不是临时找不到替代品之外，除了装逼就再没有什么意义了。即便是不需要IDE的自动补全和错误检测，个人认为代码编辑器的语法高亮和格式调整还是很重要的。手工调整格式很麻烦，而语法高亮除了看起来赏心悦目还能指出来明显的拼写错误。方便的代码编辑器notapad++、Vim，Emacs等等是很好的选择。

废话少说，言归正传。我们今天给熟悉了HTML和CSS的程序员推荐一款文本编辑器的插件——Emmet。如果你没有听说过Emmet，那你至少听说过大名鼎鼎的Zen coding吧？Emmet就是Zen coding的新名字。什么？你没有听说过？太好了，你可以继续看下去了，否则，也就没有看的必要了……

简单介绍下Emmet，官方是这么说的“Emmet is a plugin for many popular text editors which greatly improves HTML & CSS workflow”。

官方主页在 http://www.emmet.io/

Emmet作为文本编辑器的插件提供给 Eclipse/Aptana，Sublime Text 2，TextMate 1.x，Coda 1.6 and 2.x 等等编辑器作为扩展。我们以我比较喜欢的编辑器 Sublime Text 为例介绍下安装与使用方法吧。（暂时先委屈下Vim，因为Vim的插件自动补全是“Ctrl+Y+逗号/分号”，这个快捷键很不好用，而我还没有找到修改的方法  我暂时在vimrc文件里加入 imap <C-e> <C-y>;  映射到Ctrl+E，官方的重定义方法太麻烦了）

<!-- more -->

P.S. Vim版的Emmet插件代码地址在 https://github.com/mattn/zencoding-vim

Sublime Text版的插件地址在 https://github.com/sergeche/emmet-sublime ，项目的说明文件很详细的指出了如何通过Package Control: Install Package功能安装，如果你是Sublime的粉丝，这应该很简单。如果不理解也没关系，直接把代码下载后解压缩到Sublime所在目录下的Packages目录重启Sublime即可使用。

如果你使用其他的编辑器，在官方的主页上也能找到相关的下载和配置方法，我就不详细叙述了。

配置好后我们来看看如何使用。我们先来看一个基本的HTML文件几乎必写的东西：

```html
<html>
    <head>
        <title></title>
    </head>
    <body>

    </body>
</html>
```

这个框架我们怎么写呢？一个一个去拼写？姑且不说效率问题，拼写错误也是很麻烦的一件事情。

我们在Sublime中建立一个html文件，输入以下内容：

```html
html>(head>title)+body
```

输入完成后按下Tab键（windows用户请使用Ctrl+E键或自行修改快捷键），奇迹发生了，自动生成了我们想要的格式。这就是神奇的Emmet所带来的快速编写HTML和CSS的方法。只是这样吗？当然不是了，在官方提供的帮助文档里我们可以学到更多神奇的语法。地址在：http://docs.emmet.io/abbreviations/syntax/

可以使用的有>，+，^，*，( )，以及适用于CSS的#和$符号。分别表示层次关系，数量和匹配。官方有很详细的文档，甚至有动画予以说明，我就不重复造轮子了。

最后再说几句废话：插件是为了提高了我们写代码的速度，但是请别过分依赖工具。工具的使用是建立在我们掌握了本质性的东西之后用来降低重复性劳动的东西。千万不能离开了工具就什么也都干不了了，那就得不偿失了。