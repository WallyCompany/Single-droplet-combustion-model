%clear all; clc; close all;
global kb Rg Patm Na
global N xc xn dx r dr
global nu Y_O_inf MW_F MW_O MW_N MW_g Vp0 Qv Qc T_inf cp lambda_g lambda_bd rho_l rho_p K1 lambda_l dTdxs dYFdxs drs2dt alpha_l alpha Bm
global Le_l1 Le_l2 dY1dxs dY2dxs epsilon1 epsilon2 epsilon3 Ts Le_g MW_F1 MW_F2 MW_P cp_bd MW_Pr
global dp0 T_boil_F1 T_boil_F2 T_boil_Pr
%% Grid
N = 1e3; % droplet grid
xc= linspace(0.5/N,1-0.5/N,N)'; % central point in the droplet grid (non-dimensional)
xn= linspace(0,1,N+1)'; % node point in the droplet grid (non-dimensional)
dx= 1/N; % grid size in the droplet (non-dimensional)

rmax = 20; % the farthest position of the gas phase(non-dimensional)
rNum = 200;% the number of grid of the gas-phase flame
r = linspace(1,rmax,rNum);% grid of the gas phase (non-dimensional)
dr = (rmax-1)/(rNum-1); % grid size of the gas phase(non-dimensional)
tspan = linspace(0,25e-3,2e4+1); %grid of time (unit: s)

%% parameter setting
parametersetting_unvola;
    
%% preparing for initial conditions for gas phase equations variations
Ts = 300;%surface temperature (K)
rs0 = 5e-5;%droplet size (m)
rs = rs0;%setting of temporal droplet size
rho_d = rho_l1;%droplet density
rho_l = rho_l1;
Da = 50;
Ar = 50;

%% numerical simulation setting
T0 = ones( N+1,1)*Ts;
Y0 = zeros(3*(N+1),1);
Ypre = 0.2;
Y0(N+2:2*N+2) = ones(N+1,1)*Ypre*0.1;% initial mass fraction of 2-EHA
Y0(2*N+3:3*N+3)= ones(N+1,1)*Ypre*0.9; % initial mass fraction of Sn(Oct)2 as Precursor
Y0(1:N+1) = 1 - Y0(2*N+3:3*N+3) - Y0(N+2:2*N+2); % initial mass fraction of m-xylene as major fuel

[rho_d, cp_d, lambda_d, viscosity_l]  = Liquidmixpro(Y0,T0); %initial liquid properties of droplet
alpha_d0 = mean(lambda_d./rho_d./cp_d); %initial thermal diffusivity of droplet
Le0 = 5; %Lewis number for liquid species
LeS= 5*Le0; %Lewis number for solid species
phi0 = zeros(N+1,1); %initial particle volume fraction

Tinit = T0;
Yinit = Y0;
phiinit= phi0;
MW_P = MW_N;
T = ones(1,rNum)*300;% initial estimation temperature for gas phase (K)
XNs = 1;% mole fraction of inert species is initially set as 1
XPs = 0;% mole fraction of product species is initially set as 0

%% parameters for storage
Time_history=[];
Tresult_history=[];
Tgresult_history=[];
Y1result_history=[];
Y2result_history=[];
Y3result_history=[];
phiresult_history = [];
Tb_history = [];
epsilon3_history = [];
YFresult_history=[];
dmdt_history = [];
rs_history = [];
rf_history = [];
drs2dt_history = [];
B_history = [];
Ts_history= [];
lambda_g_history = [];
cp_history = [];
rho_history = [];

j0 = 3;
for i=1:1:length(tspan)-1
    for j = 1:j0
       %% liquid T and c for the gas-phase b.c. in the next step
        Ts  = Tinit(end,end); % droplet surface temperature
        Y1s = Yinit(1*N+1,end)/(1-phiinit(end));% droplet     volatile species, mass fraction
        Y2s = Yinit(2*N+2,end)/(1-phiinit(end));% droplet non-volatile species, mass fraction
        Y3s = Yinit(3*N+3,end)/(1-phiinit(end));% precursor mass fraction;
        X1s = max(Y1s/MW_F1 / (Y1s/MW_F1 + Y2s/MW_F2 + Y3s/MW_Pr),0); % droplet     volatile species (species 1), mole fraction
        X2s = max(Y2s/MW_F2 / (Y1s/MW_F1 + Y2s/MW_F2 + Y3s/MW_Pr),0); % droplet non-volatile species (species 2), mole fraction
        X3s = max(Y3s/MW_Pr / (Y1s/MW_F1 + Y2s/MW_F2 + Y3s/MW_Pr),0); % droplet non-volatile species (species 3), mole fraction
        
        XF1s = X1s*exp(Qv1*MW_F1/Rg*(1/T_boil_F1-1/Ts));% mole fraction of species 1 at the droplet surface in the gas phase
        XF2s = X2s*exp(Qv2*MW_F2/Rg*(1/T_boil_F2-1/Ts));% mole fraction of species 2 at the droplet surface in the gas phase
        XPrs = X3s*exp(Qv3*MW_Pr/Rg*(1/T_boil_Pr-1/Ts));% mole fraction of species 3 at the droplet surface in the gas phase
        
        YF1s = XF1s*MW_F1/(XF1s*MW_F1 + XF2s*MW_F2 + XPrs*MW_Pr + XNs*MW_N + XPs*MW_P);
        YF2s = XF2s*MW_F2/(XF1s*MW_F1 + XF2s*MW_F2 + XPrs*MW_Pr + XNs*MW_N + XPs*MW_P);
        YFprs= XPrs*MW_Pr/(XF1s*MW_F1 + XF2s*MW_F2 + XPrs*MW_Pr + XNs*MW_N + XPs*MW_P);

        YFs = YF1s + YF2s + YFprs;% mass fraction of the total fuel species at the droplet surface in the gas phase 
        epsilon1 = YF1s/YFs;% fractional mass vaporization rate of species 1
        epsilon2 = YF2s/YFs;% fractional mass vaporization rate of species 2
        epsilon3 = YFprs/YFs;% fractional mass vaporization rate of species 3
        MW_P = ((epsilon1/MW_F1*ST11 + epsilon2/MW_F2*ST21 + epsilon3/MW_Pr*ST31)*MW_CO2...
              + (epsilon1/MW_F1*ST12 + epsilon2/MW_F2*ST22 + epsilon3/MW_Pr*ST32)*MW_H2O)...
               /(epsilon1/MW_F1*(ST11 + ST12) + epsilon2/MW_F2*(ST21 + ST22) + epsilon3/MW_Pr*(ST31 + ST32));% molar mass of product species based on the evaporated fuel species (kg/mol)
        MW_F = 1/(epsilon1/MW_F1+epsilon2/MW_F2+epsilon3/MW_Pr); % molar fraction of fuel species (kg/mol)
        
       %% gas phase temperature and species profile
        nu = epsilon1*nu1 + epsilon2*nu2 + epsilon3*nu3;% averaged stoichiometric oxygen-to-fuel mass ratio 
        Qc = epsilon1*Qc1 + epsilon2*Qc2 + epsilon3*Qc3;% combustion heat (J/kg)
        Qv = epsilon1*Qv1 + epsilon2*Qv2 + epsilon3*Qv3;% vaporization heat (J/kg)
        Bm = (Y_O_inf/nu+YFs)/(1-YFs); % Spalding transfer number 
 
        CombCri = rs^2/rs0^2*100;% The critical combustion limit, here we assume the flame exists throughout the droplet lifetime
        CombCri0 = 0;
        if (CombCri < CombCri0)
            rf = 1;
        else
            rf = log(1+Bm)/log(1 +Y_O_inf/nu); % flame front position, non-dimensional
            YF(find(r< rf)) = -Y_O_inf/nu + (YFs+Y_O_inf/nu)*(exp(-1./r(find(r<rf))*log(1+Bm))-1)/(1/(1+Bm)-1);%distribution of fuel species inside the flame front
            YF(find(r>=rf)) = zeros(1,length(find(r>=rf)));%distribution of fuel species outside the flame front
            YO(find(r< rf)) = zeros(1,length(find(r< rf)));%distribution of oxidizer inside the flame front
            YO(find(r>=rf)) = Y_O_inf - (YFs*nu+Y_O_inf)*(exp(-1./r(find(r>=rf))*log(1+Bm))-1)/(1/(1+Bm)-1);%distribution of oxidizer outside the flame front
            YP(find(r< rf)) = (nu+1)/nu*Y_O_inf - (nu+1)/nu*Bm/(1+Bm)*Y_O_inf*(exp(-1./r(find(r< rf))*log(1+Bm))-1)/(1/(1+Bm)-1);%distribution of product inside the flame front
            YP(find(r>=rf)) = ((nu+1)*YFs+(1+nu)/nu/(1+Bm)*Y_O_inf)*(exp(-1./r(find(r>=rf))*log(1+Bm))-1)/(1/(1+Bm)-1); %distribution of product outside the flame front
            YN              = Y_N_inf - Bm/(1+Bm)*Y_N_inf*(exp(-1./r*log(1+Bm))-1)/(1/(1+Bm)-1);%distribution of the inert species
        end
        YFs = YF(1);% fuel mass fraction at the droplet surface
        YOs = YO(1);% oxidizer mass fraction at the droplet surface
        YPs = YP(1);% product species mass fraction at the droplet surface
        YNs = YN(1);% inert species mass fraction at the droplet surface
        XPs = YPs/MW_P/(YFs/MW_F + YOs/MW_O + YPs/MW_P + YNs/MW_N);% mole fraction of product species at the droplet surface
        XNs = YNs/MW_N/(YFs/MW_F + YOs/MW_O + YPs/MW_P + YNs/MW_N);% mole fraction of inert species at the droplet surface
        
        %% Physical parameter estimation
        rfp = ceil((rf - 1)/dr) + 1;% find flame position in grid
        [lambda_g,lambda_bd,cp,cp_bd,MW_P] = Gasmixpro(epsilon1,epsilon2,epsilon3,ST11,ST12,ST21,ST22,ST31,ST32,YF,YO,YP,YN,T,rfp);% estimate the gas-phase thermal conductivity (J/m/K), heat capacity(J/kg/K), molar mass of product ('g' for average value, 'bd' for surface value), 
        T(find(r< rf)) = T_inf + Y_O_inf*Qc/nu/cp + (Ts - T_inf - Y_O_inf*Qc/nu/cp)*(exp(-1./r(find(r< rf))*log(1+Bm))-1)/(1/(1+Bm)-1);%distribution of temperature inside the flame front
        T(find(r>=rf)) = T_inf + (Ts - T_inf + YFs*Qc/cp)*(exp(-1./r(find(r>=rf))*log(1+Bm))-1)/(1/(1+Bm)-1);%distribution of temperature outside the flame front

        %% Parameter
        drs2dt = -2*lambda_g/cp/rho_l(end)*log(1+Bm);% dr^2/dt (m2/s)

        %% mass and heat diffusion coefficient in liquids
        converge = 1;
        Tresult_temp = Tinit;
        Yresult_temp = Yinit;
        phiresult_temp = phiinit;
        while(converge == 1) % this iteration is for the variation of thermoproperties of liquid species
            % liquid-phase properties
            [rho_l, cp_l, lambda_l, viscosity_l] = Liquidmixpro(Yresult_temp,Tresult_temp);%estimate the density (kg/m3), heat capacity (J/kg/K), thermal conductivity(J/m/K)
            % particle properties
            ratio_lambda = 3*(lambda_s./lambda_l-1).*phiresult_temp./(lambda_s./lambda_l.*(1-phiresult_temp)+2+phiresult_temp);
            lambda_d = lambda_l.*(1+ratio_lambda); %the droplet thermal conductivity considering the influence of solid phase
            ratio_cp = phiresult_temp.*rho_s./(1-phiresult_temp)./rho_l;
            cp_d = cp_s.*ratio_cp./(ratio_cp+1) + cp_l./(ratio_cp+1);%the droplet heat capacity considering the influence of solid phase
            rho_d = phiresult_temp.*rho_s + (1-phiresult_temp).*rho_l;%the droplet density considering the influence of solid phase
            alpha_d = lambda_d./cp_d./rho_d;%the thermal diffusivity of droplet considering both liquid and solid phases
            alpha_l = lambda_l./rho_l./cp_l;%the thermal diffusivity of liquid phase
            D_d = alpha_l/Le0;%the mass diffusivity of liquid species
            D = [D_d,D_d,D_d];
            % particle properties
            DS= alpha_l./LeS;%the mass diffusivity of solid species
            % reactio term
            reactionrate = Da*alpha_d0/rs0^2.*exp(Ar*(1-T_boil_F1./Tresult_temp)).*rho_d.*Yresult_temp(2*N+3:3*N+3);
            % solve T,phi,Y equations of the droplet
            Tresult   = heattransfer(linspace(tspan(i)*(j0+1-j)/j0 + tspan(i+1)*(j-1)/j0,tspan(i+1),3),Tinit,rs,alpha_d,lambda_d,reactionrate);
            phiresult = particletransfer(linspace(tspan(i)*(j0+1-j)/j0 + tspan(i+1)*(j-1)/j0,tspan(i+1),3),phiinit,rho_d,rs,DS,reactionrate);
            Yresult = masstransfer(linspace(tspan(i)*(j0+1-j)/j0 + tspan(i+1)*(j-1)/j0,tspan(i+1),3),Yinit,phiresult,rho_l,rs,D,reactionrate);
            Y1result  = max(Yresult(1:N+1),0);
            Y2result  = max(Yresult(N+2:2*N+2),0);
            Y3result  = max(Yresult(2*N+3:3*N+3),0);
            errorT = sum(abs(Tresult - Tresult_temp))/sum(abs(Tresult_temp));
            errorY = sum(abs(Yresult - Yresult_temp))/sum(abs(Yresult_temp));
            errorphi=sum(abs(phiresult-phiresult_temp))/sum(abs(phiresult_temp));
            if(errorT < 1e-3 && errorY < 1e-3 && errorphi < 1e-3)
                converge = 0;
                Y1result  = Yresult(1:N+1);
                Y2result  = Yresult(N+2:2*N+2);
            else
                Tresult_temp = Tresult;
                Yresult_temp = Yresult;
                phiresult_temp = phiresult;
            end

        end
        Tinit = Tresult;
        Yinit = Yresult;
        phiinit = phiresult;
        if j ~= j0
            jj = (j0-j)/(j0+1-j);
            Tinit = jj.*Tresult + (1 - jj).*Tinit;
            Yinit = jj.*[Y1result;Y2result;Y3result] + (1 - jj).*Yinit;
            phiinit = jj.*phiresult + (1 - jj).*phiinit;
        else
            Tinit = Tresult; 
            Yinit = [Y1result;Y2result;Y3result];
            phiinit = phiresult;
        end
    end

    %% solve droplet shrink
    dmdt = 4*pi*rs*lambda_g/cp*log(1+Bm)/Le_g; % the variation of mass flow rate, kg/s
    rs2 = (rs^2+drs2dt*(tspan(i+1)-tspan(i)));% the variation of the r^2, m^2
    if (rs2 > 0)
        rs = sqrt(rs2);
    else
        break
    end

    Xb = Tboilpoint(Yresult,phiresult,rho_d,T_boil_F1,T_boil_F2,T_boil_Pr,Tresult); %calculate the mole fraction of vapor
    %% temporal output 
    if(mod(i,10)==0)
        Time_history=[Time_history;tspan(i+1)];
        rs_history = [rs_history;rs];

        YFresult_history=[YFresult_history;[YF1s,YF2s,YF1s+YF2s]];
        rf_history = [rf_history;rf];
        dmdt_history = [dmdt_history;dmdt];
        epsilon3_history=[epsilon3_history;epsilon3];
        Tgresult_history = [Tgresult_history;T];
        Tresult_history  = [Tresult_history;Tresult'];
        Y1result_history = [Y1result_history;Y1result'];
        Y2result_history = [Y2result_history;Y2result'];
        Y3result_history = [Y3result_history;Y3result'];
        phiresult_history= [phiresult_history;phiresult'];
        drs2dt_history = [drs2dt_history;drs2dt];
        B_history = [B_history;Bm];
        Ts_history= [Ts_history;Ts];
        lambda_g_history = [lambda_g_history;lambda_g];
        cp_history = [cp_history;cp];
        rho_history = [rho_history;rho_d(end)];
        Tb_history = [Tb_history,Xb];
       
        fprintf('step = %d, r^2 = %g, Bm = %e, epsilon3 = %e, %e \n',Time_history(end),rs^2/rs0^2*100,Bm,epsilon3,max(Xb));
        figure(1);set(gcf, 'position', [1200,-200,800,800]);
        subplot(2,2,1);
        yyaxis left; plot(r,T,'b-');           xlabel('Dimensionless radial position r/r_s');ylabel('Temperature T(K)');
        yyaxis right;plot(r,YO,'r-',r,YF,'r--');xlabel('Dimensionless radial position r/r_s');ylabel('Species mass fraction Y_i');
        set(gca, 'XScale', 'log','FontSize',14);title(['t =',num2str(tspan(i+1)),'s']);
        
        subplot(2,2,2);
        yyaxis left; plot(xn,log10(phiresult_history(end,:)),'b-');xlabel('Dimensionless radial position r/r_s');ylabel('particle volume fraction');
        yyaxis right;plot(xn,Xb,'k-');xlabel('Dimensionless radial position r/r_s');ylabel('pmix/p0');
        set(gca,'FontSize',14);title(['Xb =',num2str(max(Xb)),'s']);
        
        subplot(2,2,3);
        yyaxis left; plot(xn,Tresult_history(end,:),'b-');xlabel('Dimensionless radial position r/r_s');ylabel('Temperature T(K)');
        yyaxis right;plot(xn,Y1result_history(end,:),'m-',xn,Y2result_history(end,:),'g-',xn,Y3result_history(end,:),'k-');xlabel('Dimensionless radial position r/r_s');ylabel('Species mass fraction');
        set(gca, 'FontSize',14);

        subplot(2,2,4);
        yyaxis left;plot(Time_history/rs0^2/1e6/4,rs_history.^2/rs0^2);
        yyaxis right;plot(Time_history/rs0^2/1e6/4,Ts_history);
        set(gca,'FontSize',14);
    end
    if(max(Xb)>1) % If there is one point exceeding 1, indicating the occurrance of microexplosion
        fprintf('time = %f, dp2/dp02= %f\n',Time_history(end),rs2/rs0^2);
        break
    end
end
save(['Yprecursor=',num2str(Y0(2*N+2)+Y0(3*N+3)),'_Le=',num2str(Le0),'_Da=',num2str(Da),'_Ar=',num2str(Ar),'_Tbl=',num2str(T_boil_Pr),'_rs=',num2str(rs0),'.mat'])