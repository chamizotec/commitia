; Instalador do CommitIA para Windows (Inno Setup 6 ou superior; testado com 7.1).
; Compilar: ISCC.exe /DAppVersion=1.0.16 installer\commitia.iss
;
; - Não exige administrador para o CommitIA: instala em %LOCALAPPDATA%\commitia.
; - Git para Windows é obrigatório. Se não existir, tenta instalar com winget.
; - Adiciona a pasta ao PATH do usuário (PowerShell e CMD) e grava COMMITIA_GIT_BASH.

#ifndef AppVersion
  #define AppVersion "0.0.0-dev"
#endif

#define AppName "CommitIA"

[Setup]
AppId={{9E93A9D8-FE86-4BC7-A534-64666B6A4A34}
AppName={#AppName}
AppVersion={#AppVersion}
AppPublisher=chamizotec
AppPublisherURL=https://github.com/chamizotec/commitia
UninstallDisplayName={#AppName} {#AppVersion}
DefaultDirName={localappdata}\commitia
DisableDirPage=yes
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
ChangesEnvironment=yes
OutputDir=..\dist
OutputBaseFilename=commitia-setup
Compression=lzma2
SolidCompression=yes
WizardStyle=modern

[Languages]
Name: "brazilianportuguese"; MessagesFile: "compiler:Languages\BrazilianPortuguese.isl"

[Files]
Source: "..\bin\commitia"; DestDir: "{app}"; Flags: ignoreversion
Source: "commitia.cmd"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\LICENSE"; DestDir: "{app}"; Flags: ignoreversion

[Code]
var
  GitBashPath: string;

function FindGitBash(): string;
var
  InstallPath, Candidate: string;
begin
  Result := '';

  if RegQueryStringValue(HKLM, 'SOFTWARE\GitForWindows', 'InstallPath', InstallPath) or
     RegQueryStringValue(HKCU, 'SOFTWARE\GitForWindows', 'InstallPath', InstallPath) then
  begin
    Candidate := AddBackslash(InstallPath) + 'bin\bash.exe';
    if FileExists(Candidate) then
    begin
      Result := Candidate;
      Exit;
    end;
  end;

  Candidate := ExpandConstant('{pf}\Git\bin\bash.exe');
  if FileExists(Candidate) then
  begin
    Result := Candidate;
    Exit;
  end;

  Candidate := ExpandConstant('{localappdata}\Programs\Git\bin\bash.exe');
  if FileExists(Candidate) then
    Result := Candidate;
end;

function EnsureGit(): Boolean;
var
  ResultCode: Integer;
begin
  Result := False;
  GitBashPath := FindGitBash();
  if GitBashPath <> '' then
  begin
    Result := True;
    Exit;
  end;

  if MsgBox('O Git para Windows nao foi encontrado.' + #13#10 + #13#10 +
            'O instalador vai tentar instalar o Git com o winget. ' +
            'O Windows pode pedir permissao de administrador.' + #13#10 + #13#10 +
            'Continuar?', mbConfirmation, MB_YESNO) = IDNO then
    Exit;

  Exec('winget',
       'install --id Git.Git -e --source winget --silent --accept-package-agreements --accept-source-agreements',
       '', SW_SHOW, ewWaitUntilTerminated, ResultCode);

  GitBashPath := FindGitBash();
  if GitBashPath = '' then
  begin
    MsgBox('Nao foi possivel instalar o Git automaticamente.' + #13#10 +
           'Instale o Git para Windows em https://git-scm.com/download/win ' +
           'e execute este instalador de novo.', mbError, MB_OK);
    Exit;
  end;

  Result := True;
end;

function InitializeSetup(): Boolean;
begin
  Result := EnsureGit();
end;

procedure AddToUserPath(Dir: string);
var
  OldPath, NewPath: string;
begin
  if not RegQueryStringValue(HKCU, 'Environment', 'Path', OldPath) then
    OldPath := '';

  if Pos(';' + Uppercase(Dir) + ';', ';' + Uppercase(OldPath) + ';') > 0 then
    Exit;

  NewPath := OldPath;
  if (NewPath <> '') and (NewPath[Length(NewPath)] <> ';') then
    NewPath := NewPath + ';';
  NewPath := NewPath + Dir;

  RegWriteExpandStringValue(HKCU, 'Environment', 'Path', NewPath);
end;

procedure RemoveFromUserPath(Dir: string);
var
  OldPath, Work, NewPath: string;
  P: Integer;
begin
  if not RegQueryStringValue(HKCU, 'Environment', 'Path', OldPath) then
    Exit;

  Work := ';' + OldPath + ';';
  P := Pos(';' + Uppercase(Dir) + ';', Uppercase(Work));
  if P = 0 then
    Exit;

  Delete(Work, P, Length(Dir) + 1);
  NewPath := Copy(Work, 2, Length(Work) - 2);

  RegWriteExpandStringValue(HKCU, 'Environment', 'Path', NewPath);
end;

procedure CurStepChanged(CurStep: TSetupStep);
begin
  if CurStep = ssPostInstall then
  begin
    RegWriteStringValue(HKCU, 'Environment', 'COMMITIA_GIT_BASH', GitBashPath);
    AddToUserPath(ExpandConstant('{app}'));
  end;
end;

procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
begin
  if CurUninstallStep = usPostUninstall then
  begin
    RemoveFromUserPath(ExpandConstant('{app}'));
    RegDeleteValue(HKCU, 'Environment', 'COMMITIA_GIT_BASH');
  end;
end;
