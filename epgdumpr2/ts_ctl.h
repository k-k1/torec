#ifndef	__TS_CONTROL_H__
#define	__TS_CONTROL_H__

#include	"util.h"

typedef	struct	_SVT_CONTROL	SVT_CONTROL;
struct	_SVT_CONTROL{
	SVT_CONTROL	*next ;
	SVT_CONTROL	*prev ;
	int		event_id ;			// ���٥��ID
	int		original_network_id ;			// OriginalNetworkID
	int		transport_stream_id ;			// TransporrtStreamID
	char	servicename[MAXSECLEN] ;		// �����ӥ�̾
};

typedef	struct	_EIT_CONTROL	EIT_CONTROL;
struct	_EIT_CONTROL{
	EIT_CONTROL	*next ;
	EIT_CONTROL	*prev ;
	int		table_id ;
	int		servid ;
	int		event_id ;			// ���٥��ID
	int		content_type ;		// ����ƥ�ȥ�����
    int		yy;
    int		mm;
    int		dd;
    int		hh;
    int		hm;
	int		ss;
	int		dhh;
	int		dhm;
	int		dss;
	int		ehh;
	int		emm;
	int		ess;
	char	*title ;			// �����ȥ�
	char	*subtitle ;			// ���֥����ȥ�
};
#endif
