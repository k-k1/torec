#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "aribstr.h"
#include "util.h"

int strrep(char *buf, char *mae, char *ato)
{
    char *mituke;
	size_t maelen, atolen;
		    
	maelen = strlen(mae);
	atolen = strlen(ato);
	if (maelen == 0 || (mituke = strstr(buf, mae)) == NULL) return 0;
	memmove(mituke + atolen, mituke + maelen, strlen(buf) - (mituke + maelen - buf ) + 1);
	memcpy(mituke, ato, atolen);
	return 1;
}
int getBit(unsigned char *byte, int *pbit, int gbit) {
	int pbyte = *pbit / 8;
	unsigned char *fbyte = byte + pbyte;

	int cutbit = *pbit - (pbyte * 8);
	int lcutbit = 32 - (cutbit + gbit);

	unsigned char tbuf[4]; /* intの最大32bit */
	unsigned int tnum;

	memcpy(tbuf, fbyte, sizeof(unsigned char) * 4);

	/* 先頭バイトから不要bitをカット */
	tbuf[0] = tbuf[0] << cutbit;
	tbuf[0] = tbuf[0] >> cutbit;

	/* intにしてしまう */
	tnum = tbuf[0] << 24 | tbuf[1] << 16 | tbuf[2] << 8 | tbuf[3];

	/* 後ろの不要バイトをカット */
	tnum = tnum >> lcutbit;

	*pbit += gbit;

	return tnum;
  
}

void getStr(char *tostr, unsigned char *byte, int *pbit, int len) {
	char str[MAXSECLEN];
	int pbyte = *pbit / 8;
	unsigned char *fbyte = byte + pbyte;

	memset(str, 0, sizeof(char) * MAXSECLEN);
	memcpy(str, fbyte, len);

	*pbit += (len * 8);
  
	AribToString(tostr, str, len);

	return;
  
}

int parseOTHERdesc(unsigned char *data) {
	int boff = 0;
	int descriptor_tag;
	int descriptor_length;

	descriptor_tag = getBit(data, &boff, 8);
	descriptor_length = getBit(data, &boff, 8);

	/* printf("other desc_tag:0x%x\n", descriptor_tag); */

	return descriptor_length + 2;
}

