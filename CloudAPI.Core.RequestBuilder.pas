unit CloudAPI.Core.RequestBuilder;

interface

uses
  CloudAPI.Client.Base,
  System.Net.HttpClient,
  CloudAPI.Request,
  System.Net.Mime,
  System.Net.URLClient,
  System.Classes;

type
  TRequestBuilder = class
  private
    FClient: TCloudApiClientBase;
    FRequest: IHTTPRequest;
    FcaRequest: IcaRequest;
    FFormData: TMultipartFormData;
    FRequestBody: TStringStream;
    FUrl: TURI;
  protected
    procedure BuildHttpHeaders;
    procedure BuildCookies;
    procedure BuildQueryParameters;
    function BuildUrlSegments(const ABaseUrl: string): TURI;
    procedure BuildGetOrPosts;
    procedure BuildFiles;
    procedure BuildFormData;
    procedure BuildRequestBody;
    function DoBuild: IHTTPRequest;
  public
    constructor Create(AClient: TCloudApiClientBase; ARequest: IcaRequest);
    class function Build(AClient: TCloudApiClientBase; ARequest: IcaRequest): IHTTPRequest;
    destructor Destroy; override;
  end;

implementation

uses
  CloudAPI.Parameter,
  CloudAPI.Types,
  System.Rtti,
  System.SysUtils;

{ TRequestBuilder }

function TRequestBuilder.DoBuild: IHTTPRequest;
var
  LMethodString: string;
begin
  LMethodString := TRttiEnumerationType.GetName<TcaMethod>(FcaRequest.Method);
  FUrl := BuildUrlSegments(FClient.BaseUrl);
  BuildGetOrPosts;
  BuildQueryParameters;
  FRequest := FClient.HttpClient.GetRequest(LMethodString, FUrl);
  BuildFiles;

  BuildHttpHeaders;
  BuildCookies;
  if FcaRequest.IsMultipartFormData then
    BuildFormData
  else
    BuildRequestBody;
  Result := FRequest;
end;

class function TRequestBuilder.Build(AClient: TCloudApiClientBase; ARequest: IcaRequest): IHTTPRequest;
var
  MyClass: TRequestBuilder;
begin
  MyClass := TRequestBuilder.Create(AClient, ARequest);
  try
    Result := MyClass.DoBuild;
  finally
    MyClass.Free;
  end;
end;

procedure TRequestBuilder.BuildCookies;
var
  LParam: TcaParameter;
  LCookie: TCookie;
begin
  for LParam in FcaRequest.Cookies do
  begin
    { TODO -oMaxim Sysoev -cGeneral : �������������� ���� }
    LCookie.Name := LParam.Name;
    LCookie.Value := LParam.ValueAsString;
    FClient.HttpClient.CookieManager.AddServerCookie(LCookie, FRequest.URL);
  end;
end;

procedure TRequestBuilder.BuildFiles;
var
  LFile: TcaFileToSend;
begin
  for LFile in FcaRequest.Files do
    case LFile.Tag of
      TcaFileToSendTag.FromFile:
        FFormData.AddFile(LFile.Name, LFile.Data);
      TcaFileToSendTag.FromStream:
        FFormData.AddStream(LFile.Name, LFile.Content, LFile.Data);
    end;
end;

procedure TRequestBuilder.BuildFormData;
begin
  FFormData.Stream.Position := 0;
  FRequest.SourceStream := FFormData.Stream;
  FRequest.AddHeader('Content-Type', FFormData.MimeTypeHeader);
end;

procedure TRequestBuilder.BuildGetOrPosts;
var
  LParam: TcaParameter;
begin
  for LParam in FcaRequest.GetOrPosts do
  begin
    if FcaRequest.IsMultipartFormData then
    begin
      FFormData.AddField(LParam.Name, LParam.ValueAsString);
    end
    else
    begin
      FUrl.AddParameter(LParam.Name, LParam.ValueAsString);
    end;
  end;
end;

procedure TRequestBuilder.BuildHttpHeaders;
var
  LParam: TcaParameter;
begin
  for LParam in FcaRequest.HttpHeaders do
  begin
    FRequest.AddHeader(LParam.Name, LParam.ValueAsString);
  end;
end;

procedure TRequestBuilder.BuildQueryParameters;
var
  LParam: TcaParameter;
begin
  for LParam in FcaRequest.QueryParameters do
  begin
    FUrl.AddParameter(LParam.Name, LParam.ValueAsString);
  end;
end;

procedure TRequestBuilder.BuildRequestBody;
begin
  FRequest.SourceStream := FRequestBody;
end;

function TRequestBuilder.BuildUrlSegments(const ABaseUrl: string): TURI;
var
  LFullUrl: string;
  LParam: TcaParameter;
begin
  LFullUrl := ABaseUrl + '/' + FcaRequest.Resource;
  for LParam in FcaRequest.UrlSegments do
  begin
    LFullUrl := LFullUrl.Replace('{' + LParam.Name + '}', LParam.ValueAsString);
  end;
  Result := TURI.Create(LFullUrl);
end;

constructor TRequestBuilder.Create(AClient: TCloudApiClientBase; ARequest: IcaRequest);
begin
  FClient := AClient;
  FcaRequest := ARequest;
  if FcaRequest.IsMultipartFormData then
    FFormData := TMultipartFormData.Create
  else if FcaRequest.IsRequestBody then
    FRequestBody := TStringStream.Create(FcaRequest.RequestBody.Text);
end;

destructor TRequestBuilder.Destroy;
begin
  if FcaRequest.IsMultipartFormData then
    FFormData.Free
  else if FcaRequest.IsRequestBody then
    FRequestBody.Free;
  inherited Destroy;
end;

end.