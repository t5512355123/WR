/*
 * All code from uClibc-0.9.32. LGPL V2.1
 */
#include <ppsi/lib.h>
#include <stdlib.h>
size_t strnlen(const char *s, size_t max);

/* libc/string/strnlen.c */
size_t strnlen(const char *s, size_t max)
{
	register const char *p = s;

	while (max && *p) {
		++p;
		--max;
	}
	return p - s;
}

/* libc/string/memcpy.c */
void *memcpy(void *s1, const void *s2, size_t n)
{
	register char *r1 = s1;
	register const char *r2 = s2;

	while (n) {
		*r1++ = *r2++;
		--n;
	}
	return s1;
}

/* libc/string/memcmp.c */
int memcmp(const void *s1, const void *s2, size_t n)
{
	register const unsigned char *r1 = s1;
	register const unsigned char *r2 = s2;
	int r = 0;

	while (n-- && ((r = ((int)(*r1++)) - *r2++) == 0))
		;
	return r;
}

/* libc/string/memset.c */
void *memset(void *s, int c, size_t n)
{
	register unsigned char *p = s;

	while (n) {
		*p++ = (unsigned char) c;
		--n;
	}
	return s;
}


/* libc/string/strcpy.c */
char *strcpy(char *s1, const char *s2)
{
	register char *s = s1;

	while ( (*s++ = *s2++) != 0 )
		;
	return s1;
}

void *memmove(void *s1, const void *s2, size_t n)
{
	unsigned char *d = s1;
	const unsigned char *s = s2;

	if (d == s || n == 0)
		return s1;
	if (d < s || d >= s + n) {
		while (n--)
			*d++ = *s++;
	} else {
		d += n;
		s += n;
		while (n--)
			*--d = *--s;
	}
	return s1;
}

size_t strlen(const char *s)
{
	const char *p = s;

	while (*p)
		++p;
	return p - s;
}

char *strncpy(char *s1, const char *s2, size_t n)
{
	char *d = s1;

	while (n && (*d++ = *s2++))
		--n;
	while (n--)
		*d++ = 0;
	return s1;
}

int strcmp(const char *s1, const char *s2)
{
	while (*s1 && *s1 == *s2) {
		++s1;
		++s2;
	}
	return (unsigned char)*s1 - (unsigned char)*s2;
}

int strncmp(const char *s1, const char *s2, size_t n)
{
	while (n && *s1 && *s1 == *s2) {
		++s1;
		++s2;
		--n;
	}
	return n ? (unsigned char)*s1 - (unsigned char)*s2 : 0;
}

void bzero(void *s, size_t n)
{
	memset(s, 0, n);
}
