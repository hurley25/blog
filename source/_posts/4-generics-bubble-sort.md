title: 一个泛型冒泡排序的实现
date: 2012-12-01 14:02:00
tags:
- C
- 基础知识
categories: 基础知识
toc: false
---

无聊中，于是写了一个冒泡排序的泛型算法。算法很简单，但是个人觉得从C标准库中学到的这种泛型的思想很有益处。

```
/*
* 冒泡排序的泛型实现
*/

#include <stdio.h>
#include <string.h>

static void Swap(char *vp1, char *vp2, int width)
{
    char tmp;

    if ( vp1 != vp2 ) {
        while ( width-- ) {
            tmp = *vp1;
            *vp1++ = *vp2;
            *vp2++ = tmp;
        }
    }
}

void BubbleSort(void *base, int n, int elem_size,
                    int (*compare)( void *, void * ))
{
    int  i, last, end = n - 1;
    char *elem_addr1, *elem_addr2;

    while (end > 0) {
        last = 0;
        for (i = 0; i < end; i++) {
            elem_addr1 = (char *)base + i * elem_size;
            elem_addr2 = (char *)base + (i + 1) * elem_size;
            if (compare( elem_addr1, elem_addr2 ) > 0) {
                Swap(elem_addr1, elem_addr2, elem_size);
                last = i;
            }
        }
        end = last;
    }
}

int compare_int(void *elem1, void *elem2)
{
    return (*(int *)elem1 - *(int *)elem2);
}

int compare_double(void *elem1, void *elem2)
{
    return (*(double *)elem1 > *(double *)elem2) ? 1 : 0;
}

int main(int argc, char *argv[])
{
    int num_int[8] = {8,7,6,5,4,3,2,1};
    double num_double[8] = {8.8,7.7,6.6,5.5,4.4,3.3,2.2,1.1};
    int i;

    BubbleSort(num_int, 8, sizeof(int), compare_int);

    for (i = 0; i < 8; i++) {
        printf("%d ", num_int[i]);
    }

    printf("\n");

    BubbleSort(num_double, 8, sizeof(double), compare_double);

    for (i = 0; i < 8; i++) {
        printf("%.1f ", num_double[i]);
    }

    return 0;
}
```
