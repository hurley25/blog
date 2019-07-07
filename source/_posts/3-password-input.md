title: 控制台下星号密码输入的实现
date: 2012-11-23 14:02:00
tags:
- C
- 基础知识
categories: 基础知识
toc: false
---

最近频繁需要实现在windows控制台下输入星号密码的功能，Unix/Linux那种没有任何屏显的实现总感觉对用户不太友好。今天在自己的Linux代码库中发现了自己去年写图书馆管理系统的时候写的一个密码输入函数。索性拿来修改了接口并且重新优化了处理逻辑后移植到了windows下（其实也就是加上几句条件编译罢了）。代码如下：

```c
#ifndef _WIN32 // 如果不是WIN32环境，则要自定义getch()函数
#include <termio.h>

int getch(void)
{
     struct termios tm, tm_old;
     int fd = 0, ch;

     if (tcgetattr(fd, &tm) < 0) {
          return -1;
     }

     tm_old = tm;
     cfmakeraw(&tm);
     if (tcsetattr(fd, TCSANOW, &tm) < 0) {
          return -1;
     }

     ch = fgetc(stdin);
     if (tcsetattr(fd, TCSANOW, &tm_old) < 0) {
          return -1;
     }

     return ch;
}
#else
#include <conio.h>
#endif // _WIN32

/*
* 密码输入函数，参数 passwd 为密码缓冲区，buff_len 为缓冲区长度
*/
char *passwd_input(char *passwd, int buff_len)
{
     char str;
     int i = 0;
     int enter_num = 13;
     int backspace_num;

     #ifndef _WIN32
     backspace_num = 127;
     #else
     backspace_num = 8;
     #endif

     if (passwd == NULL || buff_len <= 0) {
          return passwd;
     }
     while (1)
     {
          // 如果没有按下退格键
          if ((str = getch()) != (char)backspace_num) {
               if (i < buff_len - 1) {
                    passwd[i++] = str;
                    printf("*");
               }
          } else {
               if (i != 0) {
                    i--;
                    printf("\b \b");
               }
          }
          // 如果按下了回车键
          if (str == (char)enter_num) {
               passwd[--i] = '\0';

               if (i != buff_len - 1) {
                   printf("\b \b");
               }
               break;
          } else if (str == -1) {
               fprintf(stderr, "Error to set termio noecho.n");
          }
     }

     return passwd;
}

/*
// 测试示例（请自行添加头文件）
int main(void)
{
      char pass[7];

      printf("亲，试试输入密码（长度限制 6）：");
      passwd_input(pass, 7);
      printf("\n%s\n", pass);

     return 0;
}
*/
```
