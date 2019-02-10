.386
MODEL FLAT, STDCALL
JUMPS
LOCALS

UNICODE=0

INCLUDE C:\TASM\W32.INC
INCLUDE C:\TASM\PE.INC

EXTRN	_wsprintfA					: PROC
EXTRN	PtInRect					: PROC

wsprintf	EQU		<_wsprintfA>

IDD_DIALOG	EQU	1000
IDC_NAME	EQU	1001
IDC_SERIAL	EQU	1002
IDC_LIST	EQU	1003

PROCESS_KILL		EQU 1004
PROCESS_REFRESH		EQU	1005
PROCESS_PRIORITY	EQU	1006
PROCESS_CREATE		EQU	1007

PRIORITY_IDLE		EQU	2000
PRIORITY_NORMAL		EQU	2001
PRIORITY_HIGH		EQU	2002
PRIORITY_REALTIME	EQU	2003

DUMP_PROCESS		EQU	3000

.DATA

stPaint		PAINTSTRUCT		<>
stRect		RECT			<>
stPoint		POINT			<>
stWinRect	RECT			<>
stCapRect	RECT			<>
stColumn	LV_COLUMN		<>
stList		LV_ITEM 		<>
stProc		PROCESSENTRY32	<>
stMemory	PROCESS_MEMORY_COUNTERS	<>
stOsVersion	OSVERSIONINFO	<>

szExeName	db "Name",0
szPID		db "PID",0
szAddress	db "Address",0
szSize		db "Size",0
szPriority	db "Priority",0

szOutput	db 40 dup (?)
szFmatx		db "%.08lX",0
szCaption	db "Process List",0
szTextName	db "Your Name:",0

szIdle		db "Idle",0
szNormal	db "Normal",0
szHigh		db "High",0
szRealtime	db "Realtime",0

szMenuKill		db "Kill Process",0
szMenuDump		db "Dump Process",0
szMenuRefresh	db "Refresh List",0
szMenuPriority	db "Set Priority",0
szMenuCreate	db "Create New",0

szErrorKill		db "This Process can't be killed ;-(",0
szErrorOs		db "Unsupported Operating System!",0
szErrorPsapi	db "Psapi.dll could not be loaded!",0
szErrorKernel	db "Kernel32.dll could not be loaded!",0

.DATA?

szUserName	db 40 dup (?)
szLongFile	db 260 dup (?)
szBuffer	db 255 dup (?)
szProcName	db 255 dup (?)

hApp		dd ?
hWinDC		dd ?
ptx			dd ?
pty			dd ?
hName		dd ?
hSnapShot	dd ?
HMENU		dd ?
dwBuffer	dd ?
hProcess	dd ?
hSubMenu	dd ?
hLib		dd ?
dwMemInfo	dd ?
hFile		dd ?
dwExitCode	dd ?

.CODE

Start:

	mov		stOsVersion.dwOSVersionInfoSize, size OSVERSIONINFO
	call	GetVersionEx, offset stOsVersion
	call	GetModuleHandleA, NULL
	mov		hApp, eax
	call	InitCommonControls
	call	DialogBoxParamA, hApp, IDD_DIALOG, NULL, offset DialogProc, NULL
	call	ExitProcess, NULL

DialogProc	PROC, hDlg:DWORD, uMsg:DWORD, WPARAM:DWORD, LPARAM:DWORD

	.IF		uMsg==WM_DESTROY || uMsg==WM_CLOSE
		call	EndDialog, hDlg, NULL
	.ELSEIF	uMsg==WM_NOTIFY
		mov		eax, LPARAM
		.IF		(NMHDR PTR [eax]).code==NM_RCLICK
			.IF		(NMHDR PTR [eax]).idFrom==IDC_LIST
				call	SendDlgItemMessage, hDlg, IDC_LIST, 1032h, NULL, NULL
				.IF		eax==TRUE
					call	SendDlgItemMessage, hDlg, IDC_LIST, LVM_GETNEXTITEM, -1, LVNI_SELECTED
					mov 	stList.lv_iSubItem, 4
					mov 	stList.lv_cchTextMax, 12
					mov		stList.lv_pszText, offset szOutput					
					call	SendDlgItemMessage, hDlg, IDC_LIST, LVM_GETITEMTEXT, eax, offset stList
					.IF		byte ptr [offset szOutput]=='I'
						mov		eax, PRIORITY_IDLE
					.ELSEIF	byte ptr [offset szOutput]=='N'
						mov		eax, PRIORITY_NORMAL
					.ELSEIF	byte ptr [offset szOutput]=='H'
						mov		eax, PRIORITY_HIGH
					.ELSEIF	byte ptr [offset szOutput]=='R'
						mov		eax, PRIORITY_REALTIME
					.ENDIF												
					call	CheckMenuRadioItem, hSubMenu, PRIORITY_IDLE, PRIORITY_REALTIME, eax, MF_BYCOMMAND
					call	GetCursorPos, offset stPoint
					call 	TrackPopupMenu, hMenu, TPM_RIGHTBUTTON, stPoint.pt_x, stPoint.pt_y, NULL, hDlg, NULL					
				.ENDIF
			.ENDIF
		.ENDIF
	.ELSEIF	uMsg==WM_INITDIALOG
		call	CreatePopupMenu
		mov		hMenu, eax
		call	CreatePopupMenu
		mov		hSubMenu, eax
		;call	AppendMenuA, hMenu, MF_STRING, PROCESS_CREATE, offset szMenuCreate			
		call	AppendMenuA, hMenu, MF_STRING, PROCESS_KILL, offset szMenuKill	
		call	AppendMenuA, hMenu, MF_STRING, DUMP_PROCESS, offset szMenuDump		
		call	AppendMenuA, hMenu, MF_POPUP, hSubMenu, offset szMenuPriority
		call	AppendMenuA, hSubMenu, MF_STRING, PRIORITY_IDLE, offset szIdle
		call	AppendMenuA, hSubMenu, MF_STRING, PRIORITY_NORMAL, offset szNormal
		call	AppendMenuA, hSubMenu, MF_STRING, PRIORITY_HIGH, offset szHigh
		call	AppendMenuA, hSubMenu, MF_STRING, PRIORITY_REALTIME, offset szRealTime
		call	AppendMenuA, HMENU, MF_SEPARATOR, NULL, NULL
		call	AppendMenuA, hMenu, MF_STRING, PROCESS_REFRESH, offset szMenuRefresh
		mov 	stColumn.imask, LVCF_FMT+LVCF_TEXT+LVCF_WIDTH+LVCF_SUBITEM
		mov 	stColumn.fmt, LVCFMT_LEFT
		call	GetDlgItem, hDlg, IDC_LIST
		call	GetClientRect, eax, offset stRect
		mov		eax, stRect.rc_right
		sub		eax, 16
		sub		eax, 246
		mov 	stColumn.lx, eax
		mov 	stColumn.iSubItem, 0
		call	SetNewColumn, hDlg, offset szExeName, 0
		mov 	stColumn.lx, 64
		call	SetNewColumn, hDlg, offset szPID, 1
		mov 	stColumn.lx, 64
		call	SetNewColumn, hDlg, offset szAddress, 2
		mov 	stColumn.lx, 64
		call	SetNewColumn, hDlg, offset szSize, 3
		mov 	stColumn.lx, 54		
		call	SetNewColumn, hDlg, offset szPriority, 4
		call	LoadProcessList, hDlg
	.ELSEIF	uMsg==WM_LBUTTONDOWN
		call	SendMessage, hDlg, WM_NCLBUTTONDOWN, HTCAPTION, NULL
	.ELSEIF	uMsg==WM_CTLCOLOREDIT || uMsg==WM_CTLCOLORSTATIC
		call	SetBkColor, WPARAM, 0000000h
		call	SetTextColor, WPARAM, 0FFFFFFh
		call	CreateSolidBrush, 0000000h
		;ret		
	.ELSEIF	uMsg==WM_COMMAND
		.IF		wParam==IDOK
			call	SendMessage, hDlg, WM_CLOSE, NULL, NULL
		.ELSEIF	wParam==PROCESS_REFRESH
			call	LoadProcessList, hDlg
		.ELSEIF	wParam==PROCESS_KILL
			call	GetValueFromList, hDlg, 1
			call	OpenProcess, PROCESS_TERMINATE, FALSE, eax
			mov		hProcess, eax
			call	GetExitCodeProcess, eax, offset dwExitCode
			call	TerminateProcess, hProcess, dwExitCode
			.IF		eax==0
				call	MessageBoxA, hDlg, offset szErrorKill, NULL, MB_OK
			.ELSE
				call	Sleep, 200
				call	LoadProcessList, hDlg
			.ENDIF
			call	CloseHandle, hProcess
		.ELSEIF	wParam==PRIORITY_IDLE
			call	GetValueFromList, hDlg, 1
			call	ChangeProcessPriority, IDLE_PRIORITY_CLASS
			call	LoadProcessList, hDlg
		.ELSEIF	wParam==PRIORITY_NORMAL
			call	GetValueFromList, hDlg, 1
			call	ChangeProcessPriority, NORMAL_PRIORITY_CLASS
			call	LoadProcessList, hDlg
		.ELSEIF	wParam==PRIORITY_HIGH
			call	GetValueFromList, hDlg, 1
			call	ChangeProcessPriority, HIGH_PRIORITY_CLASS
			call	LoadProcessList, hDlg
		.ELSEIF	wParam==PRIORITY_REALTIME
			call	GetValueFromList, hDlg, 1
			call	ChangeProcessPriority, REALTIME_PRIORITY_CLASS
			call	LoadProcessList, hDlg
		.ELSEIF	wParam==DUMP_PROCESS
			call	GetValueFromList, hDlg, 1
			mov		dwPID, eax
			call	GetValueFromList, hDlg, 2
			mov		dwAddress, eax
			call	GetValueFromList, hDlg, 3
			mov		dwSize, eax			
			call	OpenProcess, PROCESS_VM_READ, FALSE, dwPID
			mov		hProcess, eax		
			call	VirtualAlloc, NULL, dwSize, MEM_RESERVE, PAGE_READWRITE
			call	VirtualAlloc, eax, dwSize, MEM_COMMIT, PAGE_READWRITE
			mov		pMem, eax
			call	ReadProcessMemory, hProcess, dwAddress, eax, dwSize, NULL
			.IF	!eax==0
				mov		stSaveFile.on_lStructSize, size OPENFILENAME
				push	hDlg
				pop		stSaveFile.on_hwndOwner
				mov		stSaveFile.on_nMaxFile, MAX_PATH
				call	GetTextFromList, hDlg, 0
				call	GetFileTitle, eax, offset szFileName, MAX_PATH				
				mov		stSaveFile.on_lpstrFile, offset szFileName
				mov		stSaveFile.on_nMaxFileTitle, MAX_PATH
				call	GetCurrentDirectory, MAX_PATH, offset szCurrent
				mov		stSaveFile.on_lpstrInitialDir, offset szCurrent
				mov		stSaveFile.on_Flags, OFN_EXPLORER+OFN_PATHMUSTEXIST+OFN_OVERWRITEPROMPT
				mov		stSaveFile.on_lpstrFilter, offset szFileFilter				
				call	GetSaveFileName, offset stSaveFile
				.IF	!eax==0
				    call	CreateFile, offset szFileName, GENERIC_READ+GENERIC_WRITE, FILE_SHARE_READ+FILE_SHARE_WRITE, \
					   		NULL, CREATE_ALWAYS, NULL, NULL
					mov		hFile, eax
					call	WriteFile, eax, pMem, dwSize, offset dwBuffer, NULL
					call	CloseHandle, hFile
				.ENDIF
			.ENDIF
			call	VirtualFree, pMem, dwSize, MEM_DECOMMIT	
			call	VirtualFree, pMem, NULL, MEM_RELEASE	
		.ENDIF
	.ENDIF
	xor		eax, eax
	ret

DialogProc ENDP

.DATA

stSaveFile	OPENFILENAME	<>

szErrorNoMZ	db "No Valid DOS Header",0
szErrorNoPE	db "No Valid PE File",0
szFileFilter	db "All Files (*.*)",0,"*.*",0,0
szCurrent	db MAX_PATH dup (?)
szFileName	db MAX_PATH dup (?)

.DATA?

pFileMap	dd ?
hFileMap	dd ?
dwFileSize	dd ?
dwImageBase	dd ?
dwImageSize	dd ?
dwSize		dd ?
dwAddress	dd ?
hMem		dd ?
pMem		dd ?
dwOldProt	dd ?

.CODE

LoadProcessList	PROC	hDlg:DWORD
	.IF	stOsVersion.dwPlatformId==VER_PLATFORM_WIN32_WINDOWS
		call	LoadProcaddresses9x, hDlg
		.IF	!eax==INVALID_HANDLE_VALUE
			call	LoadProcessList9x, hDlg
		.ENDIF
	.ELSEIF	stOsVersion.dwPlatformId==VER_PLATFORM_WIN32_NT	
		call	LoadProcaddressesNT, hDlg
		.IF	!eax==INVALID_HANDLE_VALUE
			call	LoadProcessListNT, hDlg
		.ENDIF
	.ELSE
		call	MessageBox, hDlg, offset szErrorOs, NULL, MB_ICONERROR
	.ENDIF
	ret
LoadProcessList	ENDP

ChangeProcessPriority	PROC	dwNewPriority:DWORD
	call	OpenProcess, PROCESS_SET_INFORMATION, FALSE, eax
	mov		hProcess, eax
	call	SetPriorityClass, eax, dwNewPriority
	call	CloseHandle, hProcess
	ret
ChangeProcessPriority	ENDP

GetValueFromList	PROC	hDlg:DWORD, dwItem:DWORD
	call	SendDlgItemMessage, hDlg, IDC_LIST, LVM_GETNEXTITEM, -1, LVNI_SELECTED
	push	dwItem
	pop 	stList.lv_iSubItem
	mov 	stList.lv_cchTextMax, 12
	mov		stList.lv_pszText, offset szBuffer
	call	SendDlgItemMessage, hDlg, IDC_LIST, LVM_GETITEMTEXT, eax, offset stList
	lea		eax, szBuffer
	call	ConvertStringToHex, eax
	ret
GetValueFromList	ENDP

GetTextFromList	PROC	hDlg:DWORD, dwItem:DWORD
	call	SendDlgItemMessage, hDlg, IDC_LIST, LVM_GETNEXTITEM, -1, LVNI_SELECTED
	push	dwItem
	pop 	stList.lv_iSubItem
	mov 	stList.lv_cchTextMax, 255
	mov		stList.lv_pszText, offset szBuffer
	call	SendDlgItemMessage, hDlg, IDC_LIST, LVM_GETITEMTEXT, eax, offset stList
	lea		eax, szBuffer
	ret
GetTextFromList	ENDP

.DATA?

hSnapModule	dd ?

.DATA

stModuleEntry	MODULEENTRY32	<>

.CODE

LoadProcessList9x	PROC	hDlg:DWORD
	call	SendDlgItemMessage, hDlg, IDC_LIST, LVM_DELETEALLITEMS, NULL, NULL
	call	CreateToolhelp32Snapshot, TH32CS_SNAPPROCESS, NULL
	mov		hSnapShot, eax
	mov		stProc._Size, size PROCESSENTRY32
	call	Process32First, hSnapShot, offset stProc
	mov 	stList.lv_iItem, -1
	mov 	stList.lv_imask, LVIF_TEXT
	.WHILE	eax>0
		inc		stList.lv_iItem
		mov 	stList.lv_iSubItem, 0
		call	CharLowerA, offset stProc.szExeFile
		mov		stList.lv_pszText, offset stProc.szExeFile
		call	SendDlgItemMessage, hDlg, IDC_LIST, LVM_INSERTITEM, 0, offset stList
		mov 	stList.lv_pszText, offset szOutput
		call	ValueToListView, hDlg, stProc.th32ProcessID
		call	CreateToolhelp32Snapshot, TH32CS_SNAPMODULE, stProc.th32ProcessID
		mov		hSnapModule, eax
		mov		stModuleEntry.dw_Size, size MODULEENTRY32
		call	Module32First, hSnapModule, offset stModuleEntry		
		call	ValueToListView, hDlg, stModuleEntry.modBaseAddr
		call	ValueToListView, hDlg, stModuleEntry.modBaseSize
		call	OpenProcess, PROCESS_QUERY_INFORMATION, FALSE, stProc.th32ProcessID
		mov		hProcess, eax
		call	GetPriorityClass, eax
		.IF		eax==HIGH_PRIORITY_CLASS
			mov		stList.lv_pszText, offset szHigh
		.ELSEIF	eax==IDLE_PRIORITY_CLASS
			mov		stList.lv_pszText, offset szIdle
		.ELSEIF	eax==NORMAL_PRIORITY_CLASS
			mov		stList.lv_pszText, offset szNormal
		.ELSEIF	eax==REALTIME_PRIORITY_CLASS
			mov		stList.lv_pszText, offset szRealtime
		.ENDIF
		call	ValueToListView, hDlg, eax
		call	CloseHandle, hProcess		
		call	Process32Next, hSnapShot, offset stProc
	.ENDW
	call	CloseHandle, hSnapShot
	ret
LoadProcessList9x	ENDP

.DATA

stModuleInfo	MODULEINFO	<>

.DATA?

dwPID		dd 1024 dup (?)
dwNeeded	dd ?
dwProcs		dd ?
hMod		dd 1024 dup (?)
dwNeedMod	dd ?
dwProcID	dd ?

.CODE

LoadProcessListNT	PROC	hDlg:DWORD
	call	SendDlgItemMessage, hDlg, IDC_LIST, LVM_DELETEALLITEMS, NULL, NULL
	mov 	stList.lv_iItem, -1
	mov 	stList.lv_imask, LVIF_TEXT	
	call	EnumProcesses, offset dwPID, size dwPID, offset dwNeeded
	shr		dwNeeded, 2
	mov		dwProcs, 0
	mov		eax, dwNeeded
	.WHILE	dwProcs<eax
		lea		edx, dwPid
		mov		eax, dwProcs
		mov		edx, [edx+eax*4]
		mov		dwProcID, edx
		call	OpenProcess, PROCESS_QUERY_INFORMATION+PROCESS_VM_READ, NULL, edx
		.IF	!eax==0
			mov		hProcess, eax
			call	EnumProcessModules, eax, offset hMod, size hMod, offset dwNeedMod
			.IF !eax==0
				call	GetModuleFileNameEx, hProcess, hMod, offset szProcName, 255
				inc		stList.lv_iItem
				mov 	stList.lv_iSubItem, 0
				call	CharLowerA, offset szProcName
				mov		stList.lv_pszText, offset szProcName
				call	SendDlgItemMessage, hDlg, IDC_LIST, LVM_INSERTITEM, 0, offset stList	
				mov 	stList.lv_pszText, offset szOutput
				call	ValueToListView, hDlg, dwProcID	
				call	GetModuleInformation, hProcess, hMod, offset stModuleInfo, size MODULEINFO
				call	ValueToListView, hDlg, stModuleInfo.lpBaseOfDll 	
				call	ValueToListView, hDlg, stModuleInfo.Image_Size
				call	GetPriorityClass, hProcess
				.IF		eax==HIGH_PRIORITY_CLASS
					mov		stList.lv_pszText, offset szHigh
				.ELSEIF	eax==IDLE_PRIORITY_CLASS
					mov		stList.lv_pszText, offset szIdle
				.ELSEIF	eax==NORMAL_PRIORITY_CLASS
					mov		stList.lv_pszText, offset szNormal
				.ELSEIF	eax==REALTIME_PRIORITY_CLASS
					mov		stList.lv_pszText, offset szRealtime
				.ENDIF
				call	ValueToListView, hDlg, eax				
			.ENDIF
			call	CloseHandle, hProcess
		.ENDIF
		mov		eax, dwNeeded	
		inc		dwProcs
	.ENDW
	ret
LoadProcessListNT	ENDP

SetNewColumn	PROC	hDlg:DWORD, dwTextOffset:DWORD, dwCount:DWORD
	inc		stColumn.iSubItem
	push	dwTextOffset
	pop 	stColumn.pszText
	call	SendDlgItemMessage, hDlg, IDC_LIST, LVM_INSERTCOLUMN, dwCount, offset stColumn
	ret
SetNewColumn	ENDP

ValueToListView	PROC	hDlg:DWORD, dwValue:DWORD
	pushad
	call	ConvertHexToString, dwValue
	inc 	stList.lv_iSubItem
	call	SendDlgItemMessage, hDlg, IDC_LIST, LVM_SETITEM, 0, offset stList
	popad
	ret
ValueToListView	ENDP

ConvertStringToHex PROC szString:DWORD
	push esi
	push edx
    mov esi,szString
    xor edx,edx
@L1:
    xor eax,eax
    lodsb
    test eax,eax
    jz  @L3
    sub al,30h
    cmp al,9
    jle @L2
    sub al,7
@L2:
    shl edx,4
    add edx,eax
    jmp @L1
@L3:
    mov eax,edx
    pop	edx
    pop	esi
	RET
ConvertStringToHex ENDP

ConvertHexToString	PROC	dwValue:DWORD
	pushad
	call	wsprintf, offset szOutput, offset szFmatx, dwValue
	add		esp, 12
	popad
	ret
ConvertHexToString	ENDP

.DATA

szEnumProcesses			db "EnumProcesses",0
szGetModuleFileNameEx	db "GetModuleFileNameExA",0
szEnumProcessModules	db "EnumProcessModules",0
szGetProcessMemoryInfo	db "GetProcessMemoryInfo",0
szGetModuleBaseName		db "GetModuleBaseNameA",0
szGetModuleInformation	db "GetModuleInformation",0

EnumProcesses			dd ?
GetModuleFileNameEx		dd ?
EnumProcessModules		dd ?
GetProcessMemoryInfo	dd ?
GetModuleBaseName		dd ?
GetModuleInformation	dd ?

szProcess32First			db "Process32First",0
szCreateToolhelp32Snapshot 	db "CreateToolhelp32Snapshot",0
szProcess32Next				db "Process32Next",0

Process32First				dd ?
CreateToolhelp32Snapshot 	dd ?
Process32Next				dd ?

szPsApi		db "Psapi.dll",0
szKernel	db "Kernel32.DLL",0

LoadProcaddressesNT	PROC	hDlg:DWORD
	call	LoadLibrary, offset szPsApi
	mov		hLib, eax
	.IF	!eax==0
		call	GetProcAddress, hLib, offset szEnumProcesses
		mov		EnumProcesses, eax
		call	GetProcAddress, hLib, offset szGetModuleFileNameEx
		mov		GetModuleFileNameEx, eax
		call	GetProcAddress, hLib, offset szEnumProcessModules
		mov		EnumProcessModules, eax
		call	GetProcAddress, hLib, offset szGetProcessMemoryInfo
		mov		GetProcessMemoryInfo, eax			
		call	GetProcAddress, hLib, offset szGetModuleBaseName
		mov		GetModuleBaseName, eax				
		call	GetProcAddress, hLib, offset szGetModuleInformation
		mov		GetModuleInformation, eax
	.ELSE
		call	MessageBox, hDlg, offset szErrorPsapi, NULL, MB_ICONERROR
		mov		eax, -1
	.ENDIF
	ret
LoadProcaddressesNT	ENDP

LoadProcaddresses9x	PROC	hDlg:DWORD
	call	LoadLibrary, offset szKernel
	mov		hLib, eax	
	.IF	!eax==0
		call	GetProcAddress, hLib, offset szProcess32First
		mov		Process32First, eax	
		call	GetProcAddress, hLib, offset szCreateToolhelp32Snapshot
		mov		CreateToolhelp32Snapshot, eax	
		call	GetProcAddress, hLib, offset szProcess32Next
		mov		Process32Next, eax		
	.ELSE
		call	MessageBox, hDlg, offset szErrorKernel, NULL, MB_ICONERROR
		mov		eax, -1					
	.ENDIF
	ret
LoadProcaddresses9x	ENDP

END Start