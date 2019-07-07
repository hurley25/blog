title: Vim 编辑器的配置
date: 2013-01-09 11:02:00
tags:
- vim
- 开发工具
categories: 开发工具
toc: false
---

vim作为linux下相当常用的编辑器拥有着数不尽的追随者，可是繁琐的vim配置却让无数新手头疼不已。

网上固然有很多的博客讲述了如何配置vim作为ide来用的，但是由于时间关系，很多插件更新换代。更有甚者遇到了插件冲突，初学者更崩溃了…

关于如何配置的文章多不胜数，我就不重复造轮子了。索性直接放出自己的vim配置以供新手使用吧…有问题请留言，我尽量回复。

最终的配置参考了网上很多的博文和帖子，因为时间跨度太大就不一一列举了，对所有博主在此一并表示感谢！

先来两张图诱惑一下大家：

![](/images/7/1.png)

<!-- more -->

配置文件的的下载地址： https://github.com/hurley25/vim-set

How To Install：
 
1. 将压缩包所有文件放到家目录下即可（注意.vim目录和.vimrc是隐藏文件） 关于vimrc的配置问题，我写了比较详细的注释，大家可以参考着看看，配色文件是我比较喜欢的，这个不喜欢的话请自行更换。

2. 配置补全 能由我配置的我都配置好了，此外宏跳转还需要tags文件（就是一个补全索引文件）的支持，在vimrc里可以看到如下几行：

```
set tags+=./tags
set tags+=/usr/include/tags
set tags+=/usr/include/c++/tags
set tags+=/usr/include/Qt/tags
```

换句话说需要以上tags文件支持，每个人都要自己生成。步骤如下：

1） 确保安装了 ctags ，没有的话 sudo yum install ctags

2） 终端切换到/usr/include/目录执行 ctags * 生成tags文件。

**C++头文件使用 ctags -R –c++-kinds=+p –fields=+iaS –extra=+q .**

3） 其余目录随意，注意小目录要加 -R参数（递归搜索），即 ctags -R

但是在include目录别这么搞。因为头文件太多，搞出一个几个G的tags就不好了。

4） 其他目录添加按照格式来就好，确保tags文件存在就可以，当前工程可以在vim里按下F5键生成当前目录tags。

3. 修改 ~/.vim/bundle/vim-plugins/c-support/templates 目录下 Templates 文件的如下内容：

```
|AUTHOR| =
|AUTHORREF| =
|EMAIL| =
|COMPANY| =
|COPYRIGHT| =
```

这样每次打开vim test.c之类的新文件会自动添加相关注释和模板。

4. 介绍下这个配置常用的功能：

其实vimrc里能看到的，我简要罗列下：

1）按下wm键（非编辑模式），启动WMToggle，像不像一个IDE？

2）tab键是自动补全，很帅吧；结构体按下 . 也有补全哦。

3）按下F6，执行make编译程序，并打开quickfix窗口，显示编译信息

按下F7，光标移到上一个错误所在的行

按下F8，光标移到下一个错误所在的行 按下F9，执行make clea

这个适应需要时间的，觉得不爽的的话请自行修改vimrc。

4 ）自动补全插件clang_complete需要clang编译器支持，请先安装clang，各大发行版安装源应该都有。安装好后启动vim依旧报错的话请注释掉（引号起始是注释）.vimrc 文件里以下行：

```
let g:clang_use_library=1
```

5. 其它功能就不一一说了，请参考.vim/doc目录下的各种帮助文件吧，都很详细的。
