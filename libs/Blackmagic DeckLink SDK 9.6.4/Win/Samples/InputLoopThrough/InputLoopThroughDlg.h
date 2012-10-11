/* -LICENSE-START-
** Copyright (c) 2009 Blackmagic Design
**
** Permission is hereby granted, free of charge, to any person or organization
** obtaining a copy of the software and accompanying documentation covered by
** this license (the "Software") to use, reproduce, display, distribute,
** execute, and transmit the Software, and to prepare derivative works of the
** Software, and to permit third-parties to whom the Software is furnished to
** do so, all subject to the following:
** 
** The copyright notices in the Software and this entire statement, including
** the above license grant, this restriction and the following disclaimer,
** must be included in all copies of the Software, in whole or in part, and
** all derivative works of the Software, unless such copies or derivative
** works are solely in the form of machine-executable object code generated by
** a source language processor.
** 
** THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
** IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
** FITNESS FOR A PARTICULAR PURPOSE, TITLE AND NON-INFRINGEMENT. IN NO EVENT
** SHALL THE COPYRIGHT HOLDERS OR ANYONE DISTRIBUTING THE SOFTWARE BE LIABLE
** FOR ANY DAMAGES OR OTHER LIABILITY, WHETHER IN CONTRACT, TORT OR OTHERWISE,
** ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
** DEALINGS IN THE SOFTWARE.
** -LICENSE-END-
*/
// InputLoopThroughDlg.h : header file
//

#pragma once

#include "DeckLinkAPI_h.h"
#include "afxwin.h"

#define MAX_DECKLINK		16

class CVideoDelegate;

// CInputLoopThroughDlg dialog
class CInputLoopThroughDlg : public CDialog
{
// Construction
public:
	CInputLoopThroughDlg(CWnd* pParent = NULL);	// standard constructor
	virtual ~CInputLoopThroughDlg();

// Dialog Data
	enum { IDD = IDD_INPUTLOOPTHROUGH_DIALOG };

public:
	IDeckLink*			m_pDeckLink[MAX_DECKLINK];
	BOOL						m_bRunning;
	IDeckLinkInput*				m_pInputCard;
	IDeckLinkOutput*			m_pOutputCard;
	CVideoDelegate*				m_pDelegate;

protected:
	virtual void DoDataExchange(CDataExchange* pDX);	// DDX/DDV support

// Implementation
protected:
	HICON m_hIcon;

	// Generated message map functions
	virtual BOOL OnInitDialog();
	afx_msg void OnSysCommand(UINT nID, LPARAM lParam);
	afx_msg void OnPaint();
	afx_msg HCURSOR OnQueryDragIcon();
	DECLARE_MESSAGE_MAP()
public:
	afx_msg void OnBnClickedStartButton();
	CComboBox m_InputCardCombo;
	CComboBox m_OutputCardCombo;
	CComboBox m_VideoFormatCombo;
	CStatic m_CaptureTimeLabel;
	CStatic m_CaptureTime;
	CButton m_StartButton;
	afx_msg void OnCbnSelchangeVideoFormatCombo();
};

class CVideoDelegate : public IDeckLinkInputCallback
{
private:
	int						m_RefCount;
	CInputLoopThroughDlg*	m_pController;
	
public:
	CVideoDelegate (CInputLoopThroughDlg* pController);

	virtual HRESULT STDMETHODCALLTYPE	QueryInterface(REFIID iid, LPVOID *ppv);
	virtual ULONG STDMETHODCALLTYPE		AddRef(void);
	virtual ULONG STDMETHODCALLTYPE		Release(void);
	
	virtual HRESULT STDMETHODCALLTYPE	VideoInputFormatChanged(BMDVideoInputFormatChangedEvents notificationEvents, IDeckLinkDisplayMode* newDisplayMode, BMDDetectedVideoInputFormatFlags detectedSignalFlags);
	virtual HRESULT STDMETHODCALLTYPE	VideoInputFrameArrived(IDeckLinkVideoInputFrame* pArrivedFrame, IDeckLinkAudioInputPacket*);
};

void InputFrameArrived (IDeckLinkVideoInputFrame* pArrivedFrame, IDeckLinkAudioInputPacket*, void* pContext);