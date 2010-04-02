#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <string.h>
#include <iconv.h>

#include "aribstr.h"

#define CODE_UNKNOWN 		0	// �����ʥ���ե��å����å�(���б�)
#define CODE_KANJI 		1	// Kanji
#define CODE_ALPHANUMERIC 	2	// Alphanumeric
#define CODE_HIRAGANA 		3	// Hiragana
#define CODE_KATAKANA 		4	// Katakana
#define CODE_MOSAIC_A 		5	// Mosaic A
#define CODE_MOSAIC_B 		6	// Mosaic B
#define CODE_MOSAIC_C 		7	// Mosaic C
#define CODE_MOSAIC_D 		8	// Mosaic D
#define CODE_PROP_ALPHANUMERIC 	9	// Proportional Alphanumeric
#define CODE_PROP_HIRAGANA 	10	// Proportional Hiragana
#define CODE_PROP_KATAKANA 	11	// Proportional Katakana
#define CODE_JIS_X0201_KATAKANA 12	// JIS X 0201 Katakana
#define CODE_JIS_KANJI_PLANE_1 	13	// JIS compatible Kanji Plane 1
#define CODE_JIS_KANJI_PLANE_2 	14	// JIS compatible Kanji Plane 2
#define CODE_ADDITIONAL_SYMBOLS	15	// Additional symbols


#define TCHAR char
#define BYTE  char
#define WORD  int
#define DWORD int
#define bool  int
#define true  1
#define false 0
#define TEXT(a) a
#define _T(a) a
#define CODE_SET int

static int m_CodeG[4];
static int *m_pLockingGL;
static int *m_pLockingGR;
static int *m_pSingleGL;
	
static	BYTE m_byEscSeqCount;
static	BYTE m_byEscSeqIndex;
static	bool m_bIsEscSeqDrcs;


static	const DWORD AribToStringInternal(TCHAR *lpszDst, const BYTE *pSrcData, const DWORD dwSrcLen);
static	const DWORD ProcessCharCode(TCHAR *lpszDst, const WORD wCode, const CODE_SET CodeSet);

static	const DWORD PutKanjiChar(TCHAR *lpszDst, const WORD wCode);
static	const DWORD PutAlphanumericChar(TCHAR *lpszDst, const WORD wCode);
static	const DWORD PutHiraganaChar(TCHAR *lpszDst, const WORD wCode);
static	const DWORD PutKatakanaChar(TCHAR *lpszDst, const WORD wCode);
static	const DWORD PutJisKatakanaChar(TCHAR *lpszDst, const WORD wCode);
static	const DWORD PutSymbolsChar(TCHAR *lpszDst, const WORD wCode);

static	void ProcessEscapeSeq(const BYTE byCode);

static	void LockingShiftGL(const BYTE byIndexG);
static	void LockingShiftGR(const BYTE byIndexG);
static	void SingleShiftGL(const BYTE byIndexG);

static	const bool DesignationGSET(const BYTE byIndexG, const BYTE byCode);
static	const bool DesignationDRCS(const BYTE byIndexG, const BYTE byCode);

static WORD convertjis(DWORD);

static const bool abCharSizeTable[] =
{
	false,	// CODE_UNKNOWN					�����ʥ���ե��å����å�(���б�)
	true,	// CODE_KANJI					Kanji
	false,	// CODE_ALPHANUMERIC			Alphanumeric
	false,	// CODE_HIRAGANA				Hiragana
	false,	// CODE_KATAKANA				Katakana
	false,	// CODE_MOSAIC_A				Mosaic A
	false,	// CODE_MOSAIC_B				Mosaic B
	false,	// CODE_MOSAIC_C				Mosaic C
	false,	// CODE_MOSAIC_D				Mosaic D
	false,	// CODE_PROP_ALPHANUMERIC		Proportional Alphanumeric
	false,	// CODE_PROP_HIRAGANA			Proportional Hiragana
	false,	// CODE_PROP_KATAKANA			Proportional Katakana
	false,	// CODE_JIS_X0201_KATAKANA		JIS X 0201 Katakana
	true,	// CODE_JIS_KANJI_PLANE_1		JIS compatible Kanji Plane 1
	true,	// CODE_JIS_KANJI_PLANE_2		JIS compatible Kanji Plane 2
	true	// CODE_ADDITIONAL_SYMBOLS		Additional symbols
};

int AribToString(
	char *lpszDst, 
	const char *pSrcData, 
	const int dwSrcLen) {
  
	return AribToStringInternal(lpszDst, pSrcData, dwSrcLen);
}


const DWORD AribToStringInternal(TCHAR *lpszDst, 
								 const BYTE *pSrcData, const DWORD dwSrcLen)
{
	if(!pSrcData || !dwSrcLen || !lpszDst)return 0UL;
  
	DWORD dwSrcPos = 0UL;
	DWORD dwDstLen = 0UL;
	int   dwSrcData;
  
	// ���ֽ������
	m_byEscSeqCount = 0U;
	m_pSingleGL = NULL;

	m_CodeG[0] = CODE_KANJI;
	m_CodeG[1] = CODE_ALPHANUMERIC;
	m_CodeG[2] = CODE_HIRAGANA;
	m_CodeG[3] = CODE_KATAKANA;

	m_pLockingGL = &m_CodeG[0];
	m_pLockingGR = &m_CodeG[2];

	while(dwSrcPos < dwSrcLen){
		dwSrcData = pSrcData[dwSrcPos] & 0xFF;

		if(!m_byEscSeqCount){
      
			// GL/GR�ΰ�
			if((dwSrcData >= 0x21U) && (dwSrcData <= 0x7EU)){
				// GL�ΰ�
				const CODE_SET CurCodeSet = (m_pSingleGL)? *m_pSingleGL : *m_pLockingGL;
				m_pSingleGL = NULL;
				
				if(abCharSizeTable[CurCodeSet]){
					// 2�Х��ȥ�����
					if((dwSrcLen - dwSrcPos) < 2UL)break;
					
					dwDstLen += ProcessCharCode(&lpszDst[dwDstLen], ((WORD)pSrcData[dwSrcPos + 0] << 8) | (WORD)pSrcData[dwSrcPos + 1], CurCodeSet);
					dwSrcPos++;
				}
				else{
					// 1�Х��ȥ�����
					dwDstLen += ProcessCharCode(&lpszDst[dwDstLen], (WORD)dwSrcData, CurCodeSet);
				}
			}
			else if((dwSrcData >= 0xA1U) && (dwSrcData <= 0xFEU)){
				// GR�ΰ�
				const CODE_SET CurCodeSet = *m_pLockingGR;
				
				if(abCharSizeTable[CurCodeSet]){
					// 2�Х��ȥ�����
					if((dwSrcLen - dwSrcPos) < 2UL)break;
					
					dwDstLen += ProcessCharCode(&lpszDst[dwDstLen], ((WORD)(pSrcData[dwSrcPos + 0] & 0x7FU) << 8) | (WORD)(pSrcData[dwSrcPos + 1] & 0x7FU), CurCodeSet);
					dwSrcPos++;
				}
				else{
					// 1�Х��ȥ�����
					dwDstLen += ProcessCharCode(&lpszDst[dwDstLen], (WORD)(dwSrcData & 0x7FU), CurCodeSet);
				}
			}
			else{
				// ���楳����
				switch(dwSrcData){
				case 0x0FU	: LockingShiftGL(0U);				break;	// LS0
				case 0x0EU	: LockingShiftGL(1U);				break;	// LS1
				case 0x19U	: SingleShiftGL(2U);				break;	// SS2
				case 0x1DU	: SingleShiftGL(3U);				break;	// SS3
				case 0x1BU	: m_byEscSeqCount = 1U;				break;	// ESC
				case 0x20U	:
				case 0xA0U	: lpszDst[dwDstLen++] = TEXT(' ');	break;	// SP
				default		: break;	// ���б�
				}
			}
		}
		else{
			// ���������ץ������󥹽���
			ProcessEscapeSeq(dwSrcData);
		}
		
		dwSrcPos++;
	}

	// ��üʸ��
	lpszDst[dwDstLen] = TEXT('\0');

	return dwDstLen;
}

const DWORD ProcessCharCode(TCHAR *lpszDst, const WORD wCode, const CODE_SET CodeSet)
{
	switch(CodeSet){
	case CODE_KANJI	:
	case CODE_JIS_KANJI_PLANE_1 :
	case CODE_JIS_KANJI_PLANE_2 :
		// ���������ɽ���
		return PutKanjiChar(lpszDst, wCode);

	case CODE_ALPHANUMERIC :
	case CODE_PROP_ALPHANUMERIC :
		// �ѿ��������ɽ���
		return PutAlphanumericChar(lpszDst, wCode);

	case CODE_HIRAGANA :
	case CODE_PROP_HIRAGANA :
		// �Ҥ餬�ʥ����ɽ���
		return PutHiraganaChar(lpszDst, wCode);

	case CODE_PROP_KATAKANA :
	case CODE_KATAKANA :
		// �������ʥ����ɽ���
		return PutKatakanaChar(lpszDst, wCode);

	case CODE_JIS_X0201_KATAKANA :
		// JIS�������ʥ����ɽ���
		return PutJisKatakanaChar(lpszDst, wCode);
#if 0
	case CODE_ADDITIONAL_SYMBOLS :
		// �ɲå���ܥ륳���ɽ���
		return PutSymbolsChar(lpszDst, wCode);
#endif
	default :
		return 0UL;
	}
}

const DWORD PutKanjiChar(TCHAR *lpszDst, const WORD wCode)
{
	// JIS��Shift-JIS�����������Ѵ�
	const WORD wShiftJIS = convertjis(wCode);

#ifdef _UNICODE
	// Shift-JIS �� UNICODE
	const char szShiftJIS[3] = {(char)(wShiftJIS >> 8), (char)(wShiftJIS & 0x00FFU), '\0'};
	::MultiByteToWideChar(CP_OEMCP, MB_PRECOMPOSED, szShiftJIS, 2, lpszDst, 2);

	return 1UL;
#else
	// Shift-JIS �� Shift-JIS
	lpszDst[0] = (wShiftJIS >> 8) & 0xFF;
	lpszDst[1] = (char)(wShiftJIS & 0x00FFU);
  
	return 2UL;
#endif
}

const DWORD PutAlphanumericChar(TCHAR *lpszDst, const WORD wCode)
{
	// �ѿ���ʸ���������Ѵ�
	static const TCHAR *acAlphanumericTable = 
		TEXT("��������������������������������")
		TEXT("��������������������������������")
		TEXT("�����ɡ������ǡʡˡ��ܡ��ݡ���")
		TEXT("���������������������������䡩")
		TEXT("�����£ãģţƣǣȣɣʣˣ̣ͣΣ�")
		TEXT("�Уѣңӣԣգ֣ףأ٣ڡΡ�ϡ���")
		TEXT("������������������")
		TEXT("�������������������Сáѡ���");

#ifdef _UNICODE
	lpszDst[0] = acAlphanumericTable[wCode];

	return 1UL;
#else
	lpszDst[0] = acAlphanumericTable[wCode * 2U + 0U];
	lpszDst[1] = acAlphanumericTable[wCode * 2U + 1U];

	return 2UL;
#endif
}

const DWORD PutHiraganaChar(TCHAR *lpszDst, const WORD wCode)
{
	// �Ҥ餬��ʸ���������Ѵ�
	static const TCHAR *acHiraganaTable = 
		TEXT("��������������������������������")
		TEXT("��������������������������������")
		TEXT("��������������������������������")
		TEXT("��������������������������������")
		TEXT("�����¤äĤŤƤǤȤɤʤˤ̤ͤΤ�")
		TEXT("�ФѤҤӤԤդ֤פؤ٤ڤۤܤݤޤ�")
		TEXT("�����������������")
		TEXT("����󡡡������������֡ס�����");
	
#ifdef _UNICODE
	lpszDst[0] = acHiraganaTable[wCode];

	return 1UL;
#else
	lpszDst[0] = acHiraganaTable[wCode * 2U + 0U];
	lpszDst[1] = acHiraganaTable[wCode * 2U + 1U];

	return 2UL;
#endif
}

const DWORD PutKatakanaChar(TCHAR *lpszDst, const WORD wCode)
{
	// �������ʱѿ���ʸ���������Ѵ�
	static const TCHAR *acKatakanaTable = 
		TEXT("��������������������������������")
		TEXT("��������������������������������")
		TEXT("��������������������������������")
		TEXT("��������������������������������")
		TEXT("�����¥åĥťƥǥȥɥʥ˥̥ͥΥ�")
		TEXT("�Хѥҥӥԥե֥ץإ٥ڥۥܥݥޥ�")
		TEXT("�����������������")
		TEXT("�������������������֡ס�����");
	
#ifdef _UNICODE
	lpszDst[0] = acKatakanaTable[wCode];

	return 1UL;
#else
	lpszDst[0] = acKatakanaTable[wCode * 2U + 0U];
	lpszDst[1] = acKatakanaTable[wCode * 2U + 1U];

	return 2UL;
#endif
}

const DWORD PutJisKatakanaChar(TCHAR *lpszDst, const WORD wCode)
{
	// JIS��������ʸ���������Ѵ�
	static const TCHAR *acJisKatakanaTable = 
		TEXT("��������������������������������")
		TEXT("��������������������������������")
		TEXT("�����֡ס����򥡥������������")
		TEXT("��������������������������������")
		TEXT("�����ĥƥȥʥ˥̥ͥΥϥҥեإۥ�")
		TEXT("�ߥ������������󡫡�")
		TEXT("��������������������������������")
		TEXT("��������������������������������");
	
#ifdef _UNICODE
	lpszDst[0] = acJisKatakanaTable[wCode];

	return 1UL;
#else
	lpszDst[0] = acJisKatakanaTable[wCode * 2U + 0U];
	lpszDst[1] = acJisKatakanaTable[wCode * 2U + 1U];

	return 2UL;
#endif
}

const DWORD PutSymbolsChar(TCHAR *lpszDst, const WORD wCode)
{
	// �ɲå���ܥ�ʸ���������Ѵ�(�Ȥꤢ����ɬ�פ����ʤ�Τ���)
	static const TCHAR *aszSymbolsTable1[] =
		{
			_T("[HV]"),		_T("[SD]"),		_T("[��]"),		_T("[��]"),		_T("[MV]"),		_T("[��]"),		_T("[��]"),		_T("[��]"),			// 0x7A50 - 0x7A57	90/48 - 90/55
			_T("[��]"),		_T("[��]"),		_T("[��]"),		_T("[¿]"),		_T("[��]"),		_T("[SS]"),		_T("[��]"),		_T("[��]"),			// 0x7A58 - 0x7A5F	90/56 - 90/63
			_T("��"),		_T("��"),		_T("[ŷ]"),		_T("[��]"),		_T("[��]"),		_T("[̵]"),		_T("[��]"),		_T("[ǯ������]"),	// 0x7A60 - 0x7A67	90/64 - 90/71
			_T("[��]"),		_T("[��]"),		_T("[��]"),		_T("[��]"),		_T("[��]"),		_T("[��]"),		_T("[��]"),		_T("[��]"),			// 0x7A68 - 0x7A6F	90/72 - 90/79
			_T("[��]"),		_T("[��]"),		_T("[PPV]"),	_T("(��)"),		_T("�ۤ�")															// 0x7A70 - 0x7A74	90/80 - 90/84
		};

	static const TCHAR *aszSymbolsTable2[] =
		{
			_T("��"),		_T("��"),		_T("��"),		_T("��"),		_T("��"),		_T("��"),		_T("ǯ"),		_T("��"),			// 0x7C21 - 0x7C28	92/01 - 92/08
			_T("��"),		_T("��"),		_T("��"),		_T("Ω����"),	_T("��"),		_T("ʿ����"),	_T("Ω����"),	_T("��."),			// 0x7C29 - 0x7C30	92/09 - 92/16
			_T("��."),		_T("��."),		_T("��."),		_T("��."),		_T("��."),		_T("��."),		_T("��."),		_T("��."),			// 0x7C31 - 0x7C38	92/17 - 92/24
			_T("��."),		_T("��"),		_T("��"),		_T("��"),		_T("��"),		_T("��"),		_T("��"),		_T("��,"),			// 0x7C39 - 0x7C40	92/25 - 92/32
			_T("��,"),		_T("��,"),		_T("��,"),		_T("��,"),		_T("��,"),		_T("��,"),		_T("��,"),		_T("��,"),			// 0x7C41 - 0x7C48	92/33 - 92/40
			_T("��,"),		_T("(��)"),		_T("(��)"),		_T("(ͭ)"),		_T("(��)"),		_T("(��)"),		_T("(��)"),		_T("��"),			// 0x7C49 - 0x7C50	92/41 - 92/48
			_T("��"),		_T("��"),		_T("��"),		_T("��"),		_T("^2"),		_T("^3"),		_T("(CD)"),		_T("(vn)"),			// 0x7C51 - 0x7C58	92/49 - 92/56
			_T("(ob)"),		_T("(cb)"),		_T("(ce"),		_T("mb)"),		_T("(hp)"),		_T("(br)"),		_T("(p)"),		_T("(s)"),			// 0x7C59 - 0x7C60	92/57 - 92/64
			_T("(ms)"),		_T("(t)"),		_T("(bs)"),		_T("(b)"),		_T("(tb)"),		_T("(tp)"),		_T("(ds)"),		_T("(ag)"),			// 0x7C61 - 0x7C68	92/65 - 92/72
			_T("(eg)"),		_T("(vo)"),		_T("(fl)"),		_T("(ke"),		_T("y)"),		_T("(sa"),		_T("x)"),		_T("(sy"),			// 0x7C69 - 0x7C70	92/73 - 92/80
			_T("n)"),		_T("(or"),		_T("g)"),		_T("(pe"),		_T("r)"),		_T("(R)"),		_T("(C)"),		_T("(�)"),			// 0x7C71 - 0x7C78	92/81 - 92/88
			_T("DJ"),		_T("[��]"),		_T("Fax")																							// 0x7C79 - 0x7C7B	92/89 - 92/91
		};

	static const TCHAR *aszSymbolsTable3[] =
		{
			_T("(��)"),		_T("(��)"),		_T("(��)"),		_T("(��)"),		_T("(��)"),		_T("(��)"),		_T("(��)"),		_T("(��)"),			// 0x7D21 - 0x7D28	93/01 - 93/08
			_T("��"),		_T("��"),		_T("��"),		_T("��"),		_T("��"),		_T("��"),		_T("(��)"),		_T("��"),			// 0x7D29 - 0x7D30	93/09 - 93/16
			_T("���ܡ�"),	_T("�̻���"),	_T("�����"),	_T("�̰¡�"),	_T("������"),	_T("���ǡ�"),	_T("�����"),	_T("�̾���"),		// 0x7D31 - 0x7D38	93/17 - 93/24
			_T("���ԡ�"),	_T("�̣ӡ�"),	_T("�����"),	_T("�����"),	_T("�ΰ��"),	_T("�����"),	_T("�λ���"),	_T("��ͷ��"),		// 0x7D39 - 0x7D40	93/25 - 93/32
			_T("�κ���"),	_T("�����"),	_T("�α���"),	_T("�λء�"),	_T("������"),	_T("���ǡ�"),	_T("��"),		_T("��"),			// 0x7D41 - 0x7D48	93/33 - 93/40
			_T("Hz"),		_T("ha"),		_T("km"),		_T("ʿ��km"),	_T("hPa"),		_T("��"),		_T("��"),		_T("1/2"),			// 0x7D49 - 0x7D50	93/41 - 93/48
			_T("0/3"),		_T("1/3"),		_T("2/3"),		_T("1/4"),		_T("3/4"),		_T("1/5"),		_T("2/5"),		_T("3/5"),			// 0x7D51 - 0x7D58	93/49 - 93/56
			_T("4/5"),		_T("1/6"),		_T("5/6"),		_T("1/7"),		_T("1/8"),		_T("1/9"),		_T("1/10"),		_T("����"),			// 0x7D59 - 0x7D60	93/57 - 93/64
			_T("�ޤ�"),		_T("��"),		_T("��"),		_T("��"),		_T("��"),		_T("��"),		_T("��"),		_T("��"),			// 0x7D61 - 0x7D68	93/65 - 93/72
			_T("��"),		_T("��"),		_T("��"),		_T("��"),		_T("��"),		_T("!!"),		_T("!?"),		_T("��/��"),		// 0x7D69 - 0x7D70	93/73 - 93/80
			_T("��"),		_T("��"),		_T("��"),		_T("����"),		_T("��"),		_T("�뱫"),		_T("��"),		_T("��"),			// 0x7D71 - 0x7D78	93/81 - 93/88
			_T("��"),		_T("��"),		_T("��")																							// 0x7D79 - 0x7D7B	93/89 - 93/91
		};

	static const TCHAR *aszSymbolsTable4[] =
		{
			_T("��"),		_T("��"),		_T("��"),		_T("��"),		_T("��"),		_T("��"),		_T("��"),		_T("��"),			// 0x7E21 - 0x7E28	94/01 - 94/08
			_T("��"),		_T("��"),		_T("XI"),		_T("X��"),		_T("��"),		_T("��"),		_T("��"),		_T("��"),			// 0x7E29 - 0x7E30	94/09 - 94/16
			_T("(1)"),		_T("(2)"),		_T("(3)"),		_T("(4)"),		_T("(5)"),		_T("(6)"),		_T("(7)"),		_T("(8)"),			// 0x7E31 - 0x7E38	94/17 - 94/24
			_T("(9)"),		_T("(10)"),		_T("(11)"),		_T("(12)"),		_T("(21)"),		_T("(22)"),		_T("(23)"),		_T("(24)"),			// 0x7E39 - 0x7E40	94/25 - 94/32
			_T("(A)"),		_T("(B)"),		_T("(C)"),		_T("(D)"),		_T("(E)"),		_T("(F)"),		_T("(G)"),		_T("(H)"),			// 0x7E41 - 0x7E48	94/33 - 94/40
			_T("(I)"),		_T("(J)"),		_T("(K)"),		_T("(L)"),		_T("(M)"),		_T("(N)"),		_T("(O)"),		_T("(P)"),			// 0x7E49 - 0x7E50	94/41 - 94/48
			_T("(Q)"),		_T("(R)"),		_T("(S)"),		_T("(T)"),		_T("(U)"),		_T("(V)"),		_T("(W)"),		_T("(X)"),			// 0x7E51 - 0x7E58	94/49 - 94/56
			_T("(Y)"),		_T("(Z)"),		_T("(25)"),		_T("(26)"),		_T("(27)"),		_T("(28)"),		_T("(29)"),		_T("(30)"),			// 0x7E59 - 0x7E60	94/57 - 94/64
			_T("��"),		_T("��"),		_T("��"),		_T("��"),		_T("��"),		_T("��"),		_T("��"),		_T("��"),			// 0x7E61 - 0x7E68	94/65 - 94/72
			_T("��"),		_T("��"),		_T("��"),		_T("��"),		_T("��"),		_T("��"),		_T("��"),		_T("��"),			// 0x7E69 - 0x7E70	94/73 - 94/80
			_T("��"),		_T("��"),		_T("��"),		_T("��"),		_T("��"),		_T("��"),		_T("��"),		_T("��"),			// 0x7E71 - 0x7E78	94/81 - 94/88
			_T("��"),		_T("��"),		_T("��"),		_T("��"),		_T("(31)")															// 0x7E79 - 0x7E7D	94/89 - 94/93
		};

	// ����ܥ���Ѵ�����
	if((wCode >= 0x7A50U) && (wCode <= 0x7A74U)){
		strcpy(lpszDst, aszSymbolsTable1[wCode - 0x7A50U]);
	}
	else if((wCode >= 0x7C21U) && (wCode <= 0x7C7BU)){
		strcpy(lpszDst, aszSymbolsTable2[wCode - 0x7C21U]);
	}
	else if((wCode >= 0x7D21U) && (wCode <= 0x7D7BU)){
		strcpy(lpszDst, aszSymbolsTable3[wCode - 0x7D21U]);
	}
	else if((wCode >= 0x7E21U) && (wCode <= 0x7E7DU)){
		strcpy(lpszDst, aszSymbolsTable4[wCode - 0x7E21U]);
	}
	else{
		strcpy(lpszDst, TEXT("��"));
	}

	return strlen(lpszDst);
}

void ProcessEscapeSeq(const BYTE byCode)
{
	// ���������ץ������󥹽���
	switch(m_byEscSeqCount){
		// 1�Х�����
	case 1U	:
		switch(byCode){
			// Invocation of code elements
		case 0x6EU	: LockingShiftGL(2U);	m_byEscSeqCount = 0U;	return;		// LS2
		case 0x6FU	: LockingShiftGL(3U);	m_byEscSeqCount = 0U;	return;		// LS3
		case 0x7EU	: LockingShiftGR(1U);	m_byEscSeqCount = 0U;	return;		// LS1R
		case 0x7DU	: LockingShiftGR(2U);	m_byEscSeqCount = 0U;	return;		// LS2R
		case 0x7CU	: LockingShiftGR(3U);	m_byEscSeqCount = 0U;	return;		// LS3R

			// Designation of graphic sets
		case 0x24U	:	
		case 0x28U	: m_byEscSeqIndex = 0U;		break;
		case 0x29U	: m_byEscSeqIndex = 1U;		break;
		case 0x2AU	: m_byEscSeqIndex = 2U;		break;
		case 0x2BU	: m_byEscSeqIndex = 3U;		break;
		default		: m_byEscSeqCount = 0U;		return;		// ���顼
		}
		break;

		// 2�Х�����
	case 2U	:
		if(DesignationGSET(m_byEscSeqIndex, byCode)){
			m_byEscSeqCount = 0U;
			return;
		}
			
		switch(byCode){
		case 0x20	: m_bIsEscSeqDrcs = true;	break;
		case 0x28	: m_bIsEscSeqDrcs = true;	m_byEscSeqIndex = 0U;	break;
		case 0x29	: m_bIsEscSeqDrcs = false;	m_byEscSeqIndex = 1U;	break;
		case 0x2A	: m_bIsEscSeqDrcs = false;	m_byEscSeqIndex = 2U;	break;
		case 0x2B	: m_bIsEscSeqDrcs = false;	m_byEscSeqIndex = 3U;	break;
		default		: m_byEscSeqCount = 0U;		return;		// ���顼
		}
		break;

		// 3�Х�����
	case 3U	:
		if(!m_bIsEscSeqDrcs){
			if(DesignationGSET(m_byEscSeqIndex, byCode)){
				m_byEscSeqCount = 0U;
				return;
			}
		}
		else{
			if(DesignationDRCS(m_byEscSeqIndex, byCode)){
				m_byEscSeqCount = 0U;
				return;
			}
		}

		if(byCode == 0x20U){
			m_bIsEscSeqDrcs = true;
		}
		else{
			// ���顼
			m_byEscSeqCount = 0U;
			return;
		}
		break;

		// 4�Х�����
	case 4U	:
		DesignationDRCS(m_byEscSeqIndex, byCode);
		m_byEscSeqCount = 0U;
		return;
	}

	m_byEscSeqCount++;
}

void LockingShiftGL(const BYTE byIndexG)
{
	// LSx
	m_pLockingGL = &m_CodeG[byIndexG];
}

void LockingShiftGR(const BYTE byIndexG)
{
	// LSxR
	m_pLockingGR = &m_CodeG[byIndexG];
}

void SingleShiftGL(const BYTE byIndexG)
{
	// SSx
	m_pSingleGL  = &m_CodeG[byIndexG];
}

const bool DesignationGSET(const BYTE byIndexG, const BYTE byCode)
{
	// G�Υ���ե��å����åȤ������Ƥ�
	switch(byCode){
	case 0x42U	: m_CodeG[byIndexG] = CODE_KANJI;				return true;	// Kanji
	case 0x4AU	: m_CodeG[byIndexG] = CODE_ALPHANUMERIC;		return true;	// Alphanumeric
	case 0x30U	: m_CodeG[byIndexG] = CODE_HIRAGANA;			return true;	// Hiragana
	case 0x31U	: m_CodeG[byIndexG] = CODE_KATAKANA;			return true;	// Katakana
	case 0x32U	: m_CodeG[byIndexG] = CODE_MOSAIC_A;			return true;	// Mosaic A
	case 0x33U	: m_CodeG[byIndexG] = CODE_MOSAIC_B;			return true;	// Mosaic B
	case 0x34U	: m_CodeG[byIndexG] = CODE_MOSAIC_C;			return true;	// Mosaic C
	case 0x35U	: m_CodeG[byIndexG] = CODE_MOSAIC_D;			return true;	// Mosaic D
	case 0x36U	: m_CodeG[byIndexG] = CODE_PROP_ALPHANUMERIC;	return true;	// Proportional Alphanumeric
	case 0x37U	: m_CodeG[byIndexG] = CODE_PROP_HIRAGANA;		return true;	// Proportional Hiragana
	case 0x38U	: m_CodeG[byIndexG] = CODE_PROP_KATAKANA;		return true;	// Proportional Katakana
	case 0x49U	: m_CodeG[byIndexG] = CODE_JIS_X0201_KATAKANA;	return true;	// JIS X 0201 Katakana
	case 0x39U	: m_CodeG[byIndexG] = CODE_JIS_KANJI_PLANE_1;	return true;	// JIS compatible Kanji Plane 1
	case 0x3AU	: m_CodeG[byIndexG] = CODE_JIS_KANJI_PLANE_2;	return true;	// JIS compatible Kanji Plane 2
	case 0x3BU	: m_CodeG[byIndexG] = CODE_ADDITIONAL_SYMBOLS;	return true;	// Additional symbols
	default		: return false;		// �����ʥ���ե��å����å�
	}
}

const bool DesignationDRCS(const BYTE byIndexG, const BYTE byCode)
{
	// DRCS�Υ���ե��å����åȤ������Ƥ�
	switch(byCode){
	case 0x40U	: m_CodeG[byIndexG] = CODE_UNKNOWN;				return true;	// DRCS-0
	case 0x41U	: m_CodeG[byIndexG] = CODE_UNKNOWN;				return true;	// DRCS-1
	case 0x42U	: m_CodeG[byIndexG] = CODE_UNKNOWN;				return true;	// DRCS-2
	case 0x43U	: m_CodeG[byIndexG] = CODE_UNKNOWN;				return true;	// DRCS-3
	case 0x44U	: m_CodeG[byIndexG] = CODE_UNKNOWN;				return true;	// DRCS-4
	case 0x45U	: m_CodeG[byIndexG] = CODE_UNKNOWN;				return true;	// DRCS-5
	case 0x46U	: m_CodeG[byIndexG] = CODE_UNKNOWN;				return true;	// DRCS-6
	case 0x47U	: m_CodeG[byIndexG] = CODE_UNKNOWN;				return true;	// DRCS-7
	case 0x48U	: m_CodeG[byIndexG] = CODE_UNKNOWN;				return true;	// DRCS-8
	case 0x49U	: m_CodeG[byIndexG] = CODE_UNKNOWN;				return true;	// DRCS-9
	case 0x4AU	: m_CodeG[byIndexG] = CODE_UNKNOWN;				return true;	// DRCS-10
	case 0x4BU	: m_CodeG[byIndexG] = CODE_UNKNOWN;				return true;	// DRCS-11
	case 0x4CU	: m_CodeG[byIndexG] = CODE_UNKNOWN;				return true;	// DRCS-12
	case 0x4DU	: m_CodeG[byIndexG] = CODE_UNKNOWN;				return true;	// DRCS-13
	case 0x4EU	: m_CodeG[byIndexG] = CODE_UNKNOWN;				return true;	// DRCS-14
	case 0x4FU	: m_CodeG[byIndexG] = CODE_UNKNOWN;				return true;	// DRCS-15
	case 0x70U	: m_CodeG[byIndexG] = CODE_UNKNOWN;				return true;	// Macro
	default		: return false;		// �����ʥ���ե��å����å�
	}
}

WORD convertjis(DWORD jiscode) {
	char code[3];
	char xcode[4];
	iconv_t cd;
  
	size_t inbyte = 2;
	size_t outbyte = 4;

	const char *fptr;
	char *tptr;

	WORD rtn;

	code[0] = jiscode >> 8;
	code[1] = jiscode & 0xFF;
	code[3] = '\0';

	/*
	  cd = iconv_open("ISO-2022-JP","UTF-8");

	  fptr = code;
	  tptr = xcode;
	  iconv(cd, &fptr, &inbyte, &tptr, &outbyte);

	  iconv_close(cd);
	*/

	xcode[0] = code[0] | 0x80;
	xcode[1] = code[1] | 0x80;

	rtn = ((xcode[0] << 8) & 0xFF00) | (xcode[1] & 0xFF);

	return rtn;

}
