#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <string.h>
#include <getopt.h>
#include <iconv.h>
#include <time.h>

#include "ts.h"
#include "sdt.h"
#include "eit.h"
#include "ts_ctl.h"

typedef		struct	_ContentTYPE{
	char	*japanese ;
	char	*english ;
}CONTENT_TYPE;

#define		CAT_COUNT		16
static  CONTENT_TYPE	ContentCatList[CAT_COUNT] = {
	{ "�˥塼������ƻ", "news" },
	{ "���ݡ���", "sports" },
	{ "����", "information" },
	{ "�ɥ��", "drama" },
	{ "����", "music" },
	{ "�Х饨�ƥ�", "variety" },
	{ "�ǲ�", "cinema" },
	{ "���˥ᡦ�û�", "anime" },
	{ "�ɥ����󥿥꡼������", "documentary" },
	{ "���", "stage" },
	{ "��̣������", "hobby" },
	{ "ʡ��", "etc" },			//ʡ��
	{ "ͽ��", "etc" }, //ͽ��
	{ "ͽ��", "etc" }, //ͽ��
	{ "ͽ��", "etc" }, //ͽ��
	{ "����¾", "etc" } //����¾
};
typedef struct _TAG_STATION
{
	char	*name;
	char	*ontv;
	int		tsId;		// OriginalNetworkID
	int		onId;		// TransportStreamID
	int		svId;		// ServiceID
} STATION;

static STATION bsSta[] = {
	{ "NHK BS1", "3001.ontvjapan.com", 16625, 4, 101},
	{ "NHK BS2", "3002.ontvjapan.com", 16625, 4, 102},
	{ "NHK BSh", "3003.ontvjapan.com", 16626, 4, 103},
	{ "BS���ƥ�", "3004.ontvjapan.com", 16592, 4, 141},
	{ "BSī��", "3005.ontvjapan.com", 16400, 4, 151},
	{ "BS-i", "3006.ontvjapan.com", 16401, 4, 161},
	{ "BS����ѥ�", "3007.ontvjapan.com", 16433, 4, 171},
	{ "BS�ե�", "3008.ontvjapan.com", 16593, 4, 181},
	{ "WOWOW", "3009.ontvjapan.com", 16432, 4, 191},
	{ "WOWOW2", "3010.ontvjapan.com", 16432, 4, 192},
	{ "WOWOW3", "3011.ontvjapan.com", 16432, 4, 193},
	{ "BS11", "3013.ontvjapan.com", 16528, 4, 211},
	{ "TwellV", "3014.ontvjapan.com", 16530, 4, 222},
};

static int bsStaCount = sizeof(bsSta) / sizeof (STATION);



static STATION csSta[] = {
	{ "���������ץ饹", "1002.ontvjapan.com", 24608, 6, 237},
	{ "���ܱǲ�������ȣ�", "1086.ontvjapan.com", 24608, 6, 239},
	{ "�ե��ƥ�ӣãӣȣ�", "306ch.epgdata.ontvjapan", 24608, 6, 306},
	{ "����åץ����ͥ�", "1059.ontvjapan.com", 24704, 6, 55},
	{ "�������ͥ�", "1217.ontvjapan.com", 24736, 6, 228},
	{ "���������ȣģ�����", "800ch.epgdata.ontvjapan", 24736, 6, 800},
	{ "��������󣸣���", "801ch.epgdata.ontvjapan", 24736, 6, 801},
	{ "��������󣸣���", "802ch.epgdata.ontvjapan", 24736, 6, 802},
	{ "�売�ץ��", "100ch.epgdata.ontvjapan", 28736, 7, 100},
	{ "���󥿡�������ԣ�", "194ch.epgdata.ontvjapan", 28736, 7, 194},
	{ "�ʥ��ݡ��ġ��ţӣУ�", "1025.ontvjapan.com", 28736, 7, 256},
	{ "�ƣϣ�", "1016.ontvjapan.com", 28736, 7, 312},
	{ "���ڡ��������ԣ�", "1018.ontvjapan.com", 28736, 7, 322},
	{ "�����ȥ����󡡥ͥå�", "1046.ontvjapan.com", 28736, 7, 331},
	{ "�ȥ����󡦥ǥ����ˡ�", "1213.ontvjapan.com", 28736, 7, 334},
	{ "��ǥ����ͥ�", "1010.ontvjapan.com", 28768, 7, 221},
	{ "�������", "1005.ontvjapan.com", 28768, 7, 222},
	{ "�����ͥ�Σţã�", "1008.ontvjapan.com", 28768, 7, 223},
	{ "�β�����ͥե���", "1009.ontvjapan.com", 28768, 7, 224},
	{ "�����������饷�å�", "1003.ontvjapan.com", 28768, 7, 238},
	{ "�������������ͥ�", "1133.ontvjapan.com", 28768, 7, 292},
	{ "�����ѡ��ɥ��", "1006.ontvjapan.com", 28768, 7, 310},
	{ "���أ�", "1014.ontvjapan.com", 28768, 7, 311},
	{ "�ʥ��祸�������ͥ�", "1204.ontvjapan.com", 28768, 7, 343},
	{ "���ƥ�ݡ�����", "110ch.epgdata.ontvjapan", 28864, 7, 110},
	{ "����ե����ͥ�", "1028.ontvjapan.com", 28864, 7, 260},
	{ "�ƥ�ī�����ͥ�", "1092.ontvjapan.com", 28864, 7, 303},
	{ "�ͣԣ�", "1019.ontvjapan.com", 28864, 7, 323},
	{ "�ߥ塼���å�������", "1024.ontvjapan.com", 28864, 7, 324},
	{ "ī���˥塼������", "1067.ontvjapan.com", 28864, 7, 352},
	{ "�££å���", "1070.ontvjapan.com", 28864, 7, 353},
	{ "�ãΣΣ�", "1069.ontvjapan.com", 28864, 7, 354},
	{ "���㥹�ȡ�����", "361ch.epgdata.ontvjapan", 28864, 7, 361},
	{ "�ʥ��ݡ��ġ���", "1041.ontvjapan.com", 28896, 7, 251},
	{ "�ʥ��ݡ��ġ���", "1042.ontvjapan.com", 28896, 7, 252},
	{ "�ʥ��ݡ��ģУ�����", "1043.ontvjapan.com", 28896, 7, 253},
	{ "�ǣ��ϣң�", "1026.ontvjapan.com", 28896, 7, 254},
	{ "�����������ݡ��ġ�", "1040.ontvjapan.com", 28896, 7, 255},
	{ "���ͥץ������ͥ�", "101ch.epgdata.ontvjapan", 28928, 7, 101},
	{ "�ӣˣ١��ӣԣ��ǣ�", "1207.ontvjapan.com", 28928, 7, 290},
	{ "�����ͥ���", "305ch.epgdata.ontvjapan", 28928, 7, 305},
	{ "����-��", "1201.ontvjapan.com", 28928, 7, 333},
	{ "�ҥ��ȥ꡼�����ͥ�", "1050.ontvjapan.com", 28928, 7, 342},
	{ "��������󣸣���", "803ch.epgdata.ontvjapan", 28928, 7, 803},
	{ "��������󣸣���", "804ch.epgdata.ontvjapan", 28928, 7, 804},
	{ "�ࡼ�ӡ��ץ饹�ȣ�", "1007.ontvjapan.com", 28960, 7, 240},
	{ "����եͥåȥ��", "1027.ontvjapan.com", 28960, 7, 262},
	{ "�̣�̣ᡡ�ȣ�", "1074.ontvjapan.com", 28960, 7, 314},
	{ "�ե��ƥ�ӣ�����", "1073.ontvjapan.com", 28992, 7, 258},
	{ "�ե��ƥ�ӣ�����", "1072.ontvjapan.com", 28992, 7, 302},
	{ "���˥ޥå���", "1047.ontvjapan.com", 28992, 7, 332},
	{ "�ǥ������Х꡼", "1062.ontvjapan.com", 28992, 7, 340},
	{ "���˥ޥ�ץ�ͥå�", "1193.ontvjapan.com", 28992, 7, 341},
	{ "��-�ԣ£ӥ����륫��", "160ch.epgdata.ontvjapan", 29024, 7, 160},
	{ "�ѣ֣�", "1120.ontvjapan.com", 29024, 7, 161},
	{ "�ץ饤�ࣳ�������ԣ�", "185ch.epgdata.ontvjapan", 29024, 7, 185},
	{ "�ե��ߥ꡼���", "1015.ontvjapan.com", 29024, 7, 293},
	{ "�ԣ£ӥ����ͥ�", "3201.ontvjapan.com", 29024, 7, 301},
	{ "�ǥ����ˡ������ͥ�", "1090.ontvjapan.com", 29024, 7, 304},
	{ "MUSIC ON! TV", "1022.ontvjapan.com", 29024, 7, 325},
	{ "���å����ơ������", "1045.ontvjapan.com", 29024, 7, 330},
	{ "�ԣ£ӥ˥塼���С���", "1076.ontvjapan.com", 29024, 7, 351},
	{ "�ã��������ȥ�����", "147ch.epgdata.ontvjapan", 29056, 7, 147},
	{ "���ƥ�ǡ�", "1068.ontvjapan.com", 29056, 7, 257},
	{ "fashion TV", "5004.ontvjapan.com", 29056, 7, 291},
	{ "���ƥ�ץ饹", "300ch.epgdata.ontvjapan", 29056, 7, 300},
	{ "�����ߥ塼���å��ԣ�", "1023.ontvjapan.com", 29056, 7, 320},
	{ "Music Japan TV", "1208.ontvjapan.com", 29056, 7, 321},
	{ "���ƥ�Σţףӣ���", "2002.ontvjapan.com", 29056, 7, 350},
};

static int csStaCount = sizeof(csSta) / sizeof (STATION);
SVT_CONTROL	*svttop = NULL;
#define		SECCOUNT	4
char	title[1024];
char	subtitle[1024];
char	Category[1024];
char	ServiceName[1024];
char	ChannelPrefix[3];
iconv_t	cd ;

void	xmlspecialchars(char *str)
{
	strrep(str, "&", "&amp;");
	strrep(str, "'", "&apos;");
	strrep(str, "\"", "&quot;");
	strrep(str, "<", "&lt;");
	strrep(str, ">", "&gt;");
}



void	GetSDT(FILE *infile, SVT_CONTROL *svttop, SECcache *secs, int count)
{
	SECcache  *bsecs;

	while((bsecs = readTS(infile, secs, count)) != NULL) {
		/* SDT */
		if((bsecs->pid & 0xFF) == 0x11) {
			dumpSDT(bsecs->buf, svttop);
		}
	}
}
void	GetEIT(FILE *infile, FILE *outfile, STATION *psta, SECcache *secs, int count)
{
	SECcache  *bsecs;
	EIT_CONTROL	*eitcur ;
	EIT_CONTROL	*eitnext ;
	EIT_CONTROL	*eittop = NULL;
	char	*outptr ;
	char	*inptr ;
	size_t	ilen;
	size_t	olen;
	time_t	l_time ;
	time_t	end_time ;
	struct	tm	tl ;
	struct	tm	*endtl ;
	char	cendtime[32];
	char	cstarttime[32];

	eittop = calloc(1, sizeof(EIT_CONTROL));
	eitcur = eittop ;
	fseek(infile, 0, SEEK_SET);
	while((bsecs = readTS(infile, secs, SECCOUNT)) != NULL) {
		/* EIT */
		if((bsecs->pid & 0xFF) == 0x12) {
			dumpEIT(bsecs->buf, psta->svId, psta->onId, psta->tsId, eittop);
		}else if((bsecs->pid & 0xFF) == 0x26) {
			dumpEIT(bsecs->buf, psta->svId, psta->onId, psta->tsId, eittop);
		}else if((bsecs->pid & 0xFF) == 0x27) {
			dumpEIT(bsecs->buf, psta->svId, psta->onId, psta->tsId, eittop);
		}
	}
	eitcur = eittop ;
	while(eitcur != NULL){
		if(!eitcur->servid){
			eitcur = eitcur->next ;
			continue ;
		}
		if(eitcur->content_type > CAT_COUNT){
			eitcur->content_type = CAT_COUNT -1 ;
		}
		outptr = title ;
		memset(title, '\0', sizeof(title));
		ilen = strlen(eitcur->title);
		olen = sizeof(title);
		inptr = eitcur->title;
		iconv(cd, &inptr, &ilen, &outptr, &olen);
		xmlspecialchars(title);

		memset(subtitle, '\0', sizeof(subtitle));
		ilen = strlen(eitcur->subtitle);
		olen = sizeof(subtitle);
		outptr = subtitle ;
		inptr = eitcur->subtitle;
		iconv(cd, &inptr, &ilen, &outptr, &olen);
		xmlspecialchars(subtitle);

		memset(Category, '\0', sizeof(Category));
		ilen = strlen(ContentCatList[eitcur->content_type].japanese);
		olen = sizeof(Category);
		outptr = Category ;
		inptr = ContentCatList[eitcur->content_type].japanese;
		iconv(cd, &inptr, &ilen, &outptr, &olen);
		xmlspecialchars(Category);

		tl.tm_sec = eitcur->ss ;
		tl.tm_min = eitcur->hm ;
		tl.tm_hour = eitcur->hh ;
		tl.tm_mday = eitcur->dd ;
		tl.tm_mon = (eitcur->mm - 1);
		tl.tm_year = (eitcur->yy - 1900);
		tl.tm_wday = 0;
		tl.tm_isdst = 0;
		tl.tm_yday = 0;
		l_time = mktime(&tl);
		if((eitcur->ehh == 0) && (eitcur->emm == 0) && (eitcur->ess == 0)){
			(void)time(&l_time);
			end_time = l_time + (60 * 5);		// ��ʬ�������
		endtl = localtime(&end_time);
		}else{
			end_time = l_time + eitcur->ehh * 3600 + eitcur->emm * 60 + eitcur->ess;
			endtl = localtime(&end_time);
		}
		memset(cendtime, '\0', sizeof(cendtime));
		memset(cstarttime, '\0', sizeof(cstarttime));
		strftime(cendtime, (sizeof(cendtime) - 1), "%Y%m%d%H%M%S", endtl);
		strftime(cstarttime, (sizeof(cstarttime) - 1), "%Y%m%d%H%M%S", &tl);
#if 1
		fprintf(outfile, "  <programme start=\"%s +0900\" stop=\"%s +0900\" ",	
				cstarttime, cendtime);
		if( ChannelPrefix[0] == 'G' )
			fprintf(outfile, "channel=\"%s%s\">\n",	ChannelPrefix, psta->ontv);
		else
			fprintf(outfile, "channel=\"%s%d\">\n",	ChannelPrefix, psta->svId);

		fprintf(outfile, "    <title lang=\"ja_JP\">%s</title>\n", title);
		fprintf(outfile, "    <desc lang=\"ja_JP\">%s</desc>\n", subtitle);
		fprintf(outfile, "    <category lang=\"ja_JP\">%s</category>\n", Category);
		fprintf(outfile, "    <category lang=\"en\">%s</category>\n", ContentCatList[eitcur->content_type].english);
		fprintf(outfile, "  </programme>\n");
#else
		fprintf(outfile, "(%x:%x:%x)%s,%s,%s,%s,%s,%s\n",
					eitcur->servid, eitcur->table_id, eitcur->event_id,
					cstarttime, cendtime,
					title, subtitle,
					Category,
					ContentCatList[eitcur->content_type].english);
#endif
#if 0
		fprintf(outfile, "(%x:%x)%04d/%02d/%02d,%02d:%02d:%02d,%02d:%02d:%02d,%s,%s,%s,%s\n",
					eitcur->table_id, eitcur->event_id,
					eitcur->yy, eitcur->mm, eitcur->dd,
					eitcur->hh, eitcur->hm, eitcur->ss,
					eitcur->ehh, eitcur->emm, eitcur->ess,
					eitcur->title, eitcur->subtitle,
					ContentCatList[eitcur->content_type].japanese,
					ContentCatList[eitcur->content_type].english);
#endif
		eitnext = eitcur->next ;
		free(eitcur->title);
		free(eitcur->subtitle);
		free(eitcur);
		eitcur = eitnext ;
	}
	free(eittop);
	eittop = NULL;
}
int main(int argc, char *argv[])
{

	FILE *infile = stdin;
	FILE *outfile = stdout;
	int		arg_maxcount = 1 ;
	char	*arg_onTV ;
	int   mode = 1;
	int		staCount ;
	int   eitcnt;
	char *file;
	int   inclose = 0;
	int   outclose = 0;
	int		flag = 0 ;
	SVT_CONTROL	*svtcur ;
	SVT_CONTROL	*svtsave ;
	char	*outptr ;
	char	*inptr ;
	size_t	ilen;
	size_t	olen;
	SECcache   secs[SECCOUNT];
	int rtn;
	int		lp ;
	STATION	*pStas ;
	int		act ;

	/* ��̣�Τ���pid����� */
	memset(secs, 0,  sizeof(SECcache) * SECCOUNT);
	secs[0].pid = 0x11;
	secs[1].pid = 0x12;
	secs[2].pid = 0x26;
	secs[3].pid = 0x27;

	if(argc == 4){
		arg_onTV = argv[1];
		file = argv[2];
		if(strcmp(file, "-")) {
			infile = fopen(file, "r");
			inclose = 1;
		}
		if(strcmp(argv[3], "-")) {
			outfile = fopen(argv[3], "w+");
			outclose = 1;
		}
	}else{
		fprintf(stdout, "Usage : %s /BS <tsFile> <outfile>\n", argv[0]);
		fprintf(stdout, "Usage : %s <channelno> <tsFile> <outfile>\n", argv[0]);
		//fprintf(stdout, "ontvcode �����ͥ뼱�̻ҡ�****.ontvjapan.com �ʤ�\n");
		//fprintf(stdout, "/BS      BS�⡼�ɡ���Ĥ�TS����BS���ɤΥǡ������ɤ߹��ߤޤ���\n");
		//fprintf(stdout, "/CS      CS�⡼�ɡ���Ĥ�TS����ʣ���ɤΥǡ������ɤ߹��ߤޤ���\n");
		return 0;
	}

	if(strcmp(arg_onTV, "/BS") == 0){
		ChannelPrefix[0]='B';ChannelPrefix[1]='S';ChannelPrefix[2]=0;
		pStas = bsSta;
		staCount = bsStaCount;
		act = 0 ;
	}else if(strcmp(arg_onTV, "/CS") == 0){
		ChannelPrefix[0]='C';ChannelPrefix[1]='S';ChannelPrefix[2]=0;
		pStas = csSta;
		staCount = csStaCount;
		act = 0 ;
	}else{
		ChannelPrefix[0]='G';ChannelPrefix[1]='R';ChannelPrefix[2]=0;
		act = 1 ;
		svttop = calloc(1, sizeof(SVT_CONTROL));
		GetSDT(infile, svttop, secs, SECCOUNT);
		svtcur = svttop->next ;	//��Ƭ
		if(svtcur == NULL){
			free(svttop);
			return ;
		}

		pStas = calloc(1, sizeof(STATION));
		pStas->tsId = svtcur->transport_stream_id ;
		pStas->onId = svtcur->original_network_id ;
		pStas->svId = svtcur->event_id ;
		pStas->ontv = arg_onTV ;
		pStas->name = svtcur->servicename ;
		staCount = 1;
	}

	fprintf(outfile, "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n");
	fprintf(outfile, "<!DOCTYPE tv SYSTEM \"xmltv.dtd\">\n\n");
	fprintf(outfile, "<tv generator-info-name=\"tsEPG2xml\" generator-info-url=\"http://localhost/\">\n");

	cd = iconv_open("UTF-8", "EUC-JP");
	for(lp = 0 ; lp < staCount ; lp++){
		memset(ServiceName, '\0', sizeof(ServiceName));
		ilen = strlen(pStas[lp].name);
		olen = sizeof(ServiceName);
		outptr = ServiceName ;
		inptr = pStas[lp].name ;
		iconv(cd, &inptr, &ilen, &outptr, &olen);
		xmlspecialchars(ServiceName);

		if( ChannelPrefix[0] == 'G' )
			fprintf(outfile, "  <channel id=\"%s%s\">\n", ChannelPrefix, pStas[lp].ontv);
		else
			fprintf(outfile, "  <channel id=\"%s%d\">\n", ChannelPrefix, pStas[lp].svId);
		fprintf(outfile, "    <display-name lang=\"ja_JP\">%s</display-name>\n", ServiceName);
		fprintf(outfile, "  </channel>\n");
	}
	for(lp = 0 ; lp < staCount ; lp++){
		GetEIT(infile, outfile, &pStas[lp], secs, SECCOUNT);
	}
	fprintf(outfile, "</tv>\n");
	if(inclose) {
		fclose(infile);
	}

	if(outclose) {
		fclose(outfile);
	}
	iconv_close(cd);
	if(act){
		free(pStas);
		svtcur = svttop ;	//��Ƭ
		while(svtcur != NULL){
			svtsave = svtcur->next ;
			free(svtcur);
			svtcur = svtsave ;
		}
	}

	return 0;
}
