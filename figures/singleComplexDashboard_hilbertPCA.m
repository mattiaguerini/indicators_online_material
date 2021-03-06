function [EL,ELg,ALc,ALcs,GDPcurrent,GDPcorrect,ExVar,IX_orig,IX_1st,IX_1gdp,collinearity,RMSE]=singleComplexDashboard_hilbertPCA(country);
%  Matlab code, Complex PCA estiation of indicators 

%% IMPORT 42 indicators for 21 years
    [IndexTable]=OECDindicators(country); % Loading the indicators from OECD 
    Index=table2array(IndexTable)'; % each column represents a single year for different indicators
    
    [in,jn]=find(isnan(Index)); % looking for empty entries
    del=unique(in);
    NamesIndex=IndexTable.Properties.VariableNames;
    NamesIndex(del)=[];
    
    Index(del,:)=[]; % skip empty indicators

[IndexH]=ComplexGDP_complexify(Index); % complexification of standardized first level signals
    

IndexH=IndexH(1:end-1,:); % last row is the GDPchangePP 

%% GDP current prices from World Bank 
warning('off')
M = readtable('/home/fabio/MatlabOakMint/SciencesPo_nice19/BeyondGDP_M/data/GDPconstantcapitaWB.csv');
f=find(strcmpi(M.CountryCode,country));
warning('on')

GDPcu=M{f,6:end};

gd=[0 diff(GDPcu)];
mu=mean(gd);
ss=std(gd);

gdn=normalize(gd);


Ygdpmode=hilbert(gdn); % complexification of standardized first level of Real GDP per capita
%%
%% Hilbert PCA with eigenvectors, eigenvalues and scores (eigenmodes)
[D,L,E,r,ph,~]=ComplexGDP_eigenmode(IndexH);

[N,T]=size(IndexH);
R=corrcoef(IndexH'); % since each row is an observation and each column is a variable.
[V,Dii]=eig(R);
eigV=sort(diag(Dii),'descend');
ExVar=100*eigV(1)./sum(eigV)

%% EIGEN-MODES
ModeL=V'*IndexH; % calculations of eigenmodes(scores) as complex components which modulate the eigenevector
I=abs(ModeL).^2; % intensity

IndexHa =  V*ModeL; % Reconstructed sequence (indentical to the original time series)

% Selection of the first (dominant) egienvecor
V1=V;
V1(:,1:end-1)=0;
ModeLw=ModeL;
ModeLw(1:end-1,:)=0;


modeD=(ModeL(end,:)); % Dominant EigenMode
EV=eigV(1);% Dominant Eigenvector


%% Correlation GDP main Mode

ALC=corrcoef(Ygdpmode,modeD);
ALc=abs(ALC(1,2));

%% RSS for Confidence interval of random coorelations
S=5000;
k=1;
while k<=S
        sr=randi(T);
        ssr=randi(T);
        ModelSa=circshift(ModeL(end,:),sr);
        gdpmodeS=circshift(Ygdpmode(:),ssr); 
        CAS=corrcoef(gdpmodeS,ModelSa);
        ALcs(k,:)=abs(CAS(1,2));
        k=k+1;
end
[h,pA,ci,zval] = ztest(ALc,mean(ALcs),std(ALcs));
pA=pA*100
h;

%% 
%% FIX GDP
M=(modeD);

[DTWdist,ix,iy] = dtw(M,Ygdpmode,'absolute');


%% RECONTRUCTION of TIME SEIRES 
IndexHa1st= V1*ModeLw; % Reconstructed with dominand eigenvector


 IX_orig=IndexH;
 IX_1st=IndexHa1st;
 %% Table of Correlations
 for k=1:N
     [Cch] = corrcoef(IX_orig(k,:),IX_1st(k,:));
     [Cc,pp,ll,lu] = corrcoef(real(IX_orig(k,:)),real(IX_1st(k,:)));
     Rx(k,:)=abs(Cch(1,2));
     Px(k,:)= pp(1,2);
     RL(k,:)=abs(ll(1,2));
     RU(k,:)=abs(lu(1,2));
     Warp(k,:) = dtw(IX_orig(k,:),IX_1st(k,:));
 end

 EL=table;
 EL.indicator=char(NamesIndex(2:end-1)');
 EL.correlation=Rx;
 EL.significance=Px;
 EL.RMS = sqrt( mean( (1-real(IX_1st)./real(IX_orig)).^2,2) );
 EL.timewarp=Warp;
 EL.order=(1:N)';
 
 writetable(EL,'Dominant_indicators.csv')
 

 

%% Reconstruct by GDP mode
GDPmode=ModeLw;
Ygdp_mode=Ygdpmode;%*std(M)+mean(M);
GDPmode(end,:)=Ygdp_mode;


%% Normalization of the new eigenvector of the GDP-eigenmode
 
V1p=IndexHa1st * pinv(GDPmode); % using the eigenmode we find the eigenvector which describes the time series
alf=modeD * pinv(Ygdp_mode);
abs(alf)

size((Ygdp_mode'))
size(IndexH)
V1p=IndexH * Ygdp_mode'./(Ygdp_mode*Ygdp_mode');
%IndexHa1a1=V1p*Ygdp_mode;
size(alf)
size(GDPmode)
size(V1)
IndexHa1a1=alf*V1*GDPmode;



IX_1gdp=(IndexHa1a1);
%  
 %% Table of Correlations with GDP (NON va bene correlare GDP con componenti del GDP)
 for k=1:N
     [Cc,pp,ll,lu] = corrcoef(real(IX_orig(k,:)),real(IX_1gdp(k,:)));
     [Cch] = corrcoef(IX_orig(k,:),IX_1gdp(k,:));
     Rxg(k,:)=abs(Cch(1,2));
     Pxg(k,:)= pp(1,2);
     RLg(k,:)=abs(ll(1,2));
     RUg(k,:)=abs(lu(1,2));
     Warpg(k,:) = dtw(IX_orig(k,:),IX_1gdp(k,:));
 end

 ELg=table;
 ELg.indicator=char(NamesIndex(2:end-1)');
 ELg.PRMSE_PC=100*sqrt( mean( ( (real(IX_orig)-real(IX_1st)) ).^2,2)./sum(real(IX_orig).^2,2));
 ELg.PRMSE_GDP=100*sqrt( mean( ( (real(IX_orig)-real(IX_1gdp))).^2,2)./sum(real(IX_orig).^2,2));
 %ELg.timewarp=Warpg;
 ELg.correlation_PC=Rx;
 ELg.correlation_GDP=Rxg;
 ELg.pvalue_PC=Px;
 ELg.pvalue_GDP=Pxg;
  ELg.order=(1:N)';
 %ELg.timewarp_Factor=Warp;



EVe=(V1p(:,end)'*V1p(:,end))/(V1(:,end)'*V1(:,end));
sqrt(V1p(:,end)'*V1p(:,end))/sqrt(V1(:,end)'*V1(:,end));
EV1=EV/(sqrt(V1p(:,end)'*V1p(:,end))/sqrt(V1(:,end)'*V1(:,end)));

rango2=rank([V1(:,end) , V1p],1e-1)
kk=V1p(:,end)-V1(:,end);


xx=V1p(:,end);
yy=V1(:,end);
collinearity = abs(yy' * xx) / ( norm(xx) * norm(yy) )

size(Ygdpmode)

%% PLOTS

grig=[.9 .9 .9];
grig2=[0.98 0.98 0.98];




GDPcurrent=(real(Ygdpmode));


RMSE = sqrt(mean(abs(kk - mean(kk)).^2)); 
DD=mean(kk);


Yg=real(alf.*Ygdpmode);

GDPcorrect=(Yg);





function Cs = DgetCosineSimilarity(x,y)
% 
% call:
% 
%      Cs = getCosineSimilarity(x,y)
%      
% Compute Cosine Similarity between vectors x and y.
% x and y have to be of same length. The interpretation of 
% cosine similarity is analogous to that of a Pearson Correlation
% 
% R.G. Bettinardi
% -----------------------------------------------------------------
if isvector(x)==0 || isvector(y)==0
    error('x and y have to be vectors!')
end
if length(x)~=length(y)
    error('x and y have to be same length!')
end
xy   = dot(x,y);
nx   = norm(x);
ny   = norm(y);
nxny = nx*ny;
Cs   = xy/nxny;



 
