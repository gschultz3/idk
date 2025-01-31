function [d, dz] = densification(denIdx, aIdx, swIdx, adThresh, d, T, dz, C, dt, re, Tmean, dIce)

%% THIS NEEDS TO BE DOUBLE CHECKED AS THERE SEAMS TO BE LITTLE DENSIFICATION IN THE MODEL OUTOUT [MAYBE COMPATION IS COMPNSATED FOR BY TRACES OF SNOW???]

%% FUNCTION INFO

% Author: Alex Gardner, University of Alberta
% Date last modified: FEB, 2008 

% Description: 
%   computes the densification of snow/firn using the emperical model of
%   Herron and Langway (1980) or the semi-emperical model of Anthern et al.
%   (2010)

% Inputs:
%   denIdx = densification model to use:
%       1 = emperical model of Herron and Langway (1980)
%       2 = semi-imerical model of Anthern et al. (2010)
%       3 = physical model from Appendix B of Anthern et al. (2010)
%   d   = initial snow/firn density [kg m-3]
%   T   = temperature [K]
%   dz  = grid cell size [m]
%   C   = average accumulation rate [kg m-2 yr-1]
%   dt  = time lapsed [s]
%   re  = effective grain radius [mm];
%   Ta  = mean annual temperature                                          

% Reference: 
% Herron and Langway (1980), Anthern et al. (2010)

%% FOR TESTING
% denIdx = 2;
% d = 800;
% T = 270;
% dz = 0.005;
% C = 200;
% dt = 60*60;
% re = 0.7;
% Tmean = 273.15-18;

%% MAIN FUNCTION

Dtol = 1e-11;
Ptol = 1e-6;

% specify constants
dt      = dt / 86400;  % convert from [s] to [d]
R       = 8.314;       % gas constant [mol-1 K-1]
CtoK    = 273.15;      % Kelvin to Celcius conversion/ice melt. point T in K
% Ec    = 60           % activation energy for self-diffusion of water
%                      % molecules through the ice tattice [kJ mol-1]
% Eg    = 42.4         % activation energy for grain growth [kJ mol-1]


% initial mass
mass_init = d .* dz;

% calculate new snow/firn density for:
%   snow with densities <= 550 [kg m-3]
%   snow with densities > 550 [kg m-3]
idx = d <= 550.0+Dtol;
switch denIdx
	case 1 % Herron and Langway (1980)
		c0 = (11 * exp(-10160 ./ (T(idx) * R))) .* C/1000;
		c1 = (575 * exp(-21400 ./ (T(~idx)* R))) .* (C/1000)^0.5;

	case 2 % Arthern et al. (2010) [semi-emperical]
		% common variable
		% NOTE: Ec=60000, Eg=42400 (i.e. should be in J not kJ)
		H = exp((-60000./(T * R)) + (42400./(Tmean .* R))) ...     
			.* (C * 9.81);

		c0 = 0.07 * H(idx);
		c1 = 0.03 * H(~idx);

	case 3 % Arthern et al. (2010) [physical model eqn. B1]
		% calcualte overburden pressure
		obp =[0;  (cumsum(dz(1:end-1)) .* d(1:end-1))];

		% common variable
		H = exp((-60000./(T * R))) .* obp ./ (re/1000).^2;
		c0 = 9.2E-9 * H(idx);
		c1 = 3.7E-9 * H(~idx);

	case 4 % Li and Zwally (2004)
		c0 = (C./dIce) .* max(139.21 - 0.542*Tmean,1).*8.36.*max(CtoK - T,1.0) .^ -2.061;
		c1 = c0;
		c0 = c0(idx);
		c1 = c1(~idx);

	case 5 % Helsen et al. (2008)
		% common variable
		c0 = (C./dIce) .* max(76.138 - 0.28965*Tmean,1).*8.36.*max(CtoK - T,1.0) .^ -2.061;
		c1 = c0;
		c0 = c0(idx);
		c1 = c1(~idx);

	case 6 % Ligtenberg and others (2011) [semi-emperical], Antarctica
		% common variable
		% From literature: H = exp((-60000.0/(Tmean * R)) + (42400.0/(Tmean * R))) * (C * 9.81);
		H = exp((-60000.0./(T * R)) + (42400.0./(Tmean .* R))) .* (C .* 9.81);
		c0arth = 0.07 * H;
		c1arth = 0.03 * H;
		% ERA5 new aIdx=1, swIdx=0
		if aIdx==1 && swIdx==0
			if abs(adThresh - 820.0) < Dtol
				% ERA5 v4 (Paolo et al., 2023)
				M0 = max(1.5131 - (0.1317 * log(C)),0.25);
				M1 = max(1.8819 - (0.2158 * log(C)),0.25);
			else
				% ERA5 new aIdx=1, swIdx=0
				%M0 = max(1.8785 - (0.1811 * log(C)),0.25);
				%M1 = max(2.0005 - (0.2346 * log(C)),0.25);
				% ERA5 new aIdx=1, swIdx=0, bare ice
				M0 = max(1.8422 - (0.1688 * log(C)),0.25);
				M1 = max(2.4979 - (0.3225 * log(C)),0.25);
			end
		% ERA5 new aIdx=2, swIdx=1
		elseif aIdx<3 && swIdx>0
			M0 = max(2.2191 - (0.2301 * log(C)),0.25);
			M1 = max(2.2917 - (0.2710 * log(C)),0.25);
		end

		% ERA5 new aIdx=2, swIdx=0
		%elseif (aIdx==2)
		%From Ligtenberg
		%H = exp((-60000.0/(Tmean * R)) + (42400.0/(Tmean * R))) * (C * 9.81);
		%M0 = max(1.435 - (0.151 * log(C)),0.25);
		%M1 = max(2.366 - (0.293 * log(C)),0.25);
		%RACMO callibration, default (Gardner et al., 2023)
		M0 = max(1.6383 - (0.1691 * log(C)),0.25);
		M1 = max(1.9991 - (0.2414 * log(C)),0.25);
		c0 = M0*c0arth(idx);
		c1 = M1*c1arth(~idx);

	case 7 % Kuipers Munneke and others (2015) [semi-emperical], Greenland
		% common variable
		% From literature: H = exp((-60000.0/(T[i] * R)) + (42400.0/(T[i] * R))) * (C * 9.81);
		H = exp((-60000.0./(T * R)) + (42400.0./(Tmean .* R))) .* (C .* 9.81);

		c0arth = 0.07 * H;
		c1arth = 0.03 * H;
		% ERA5 new aIdx=1, swIdx=0
		if aIdx==1 && swIdx==0
			if abs(adThresh - 820.0) < Dtol
				% ERA5 v4 
				M0 = max(1.3566 - (0.1350 * log(C)),0.25);
				M1 = max(1.8705 - (0.2290 * log(C)),0.25);
			else
				% ERA5 new aIdx=1, swIdx=0
				%M0 = max(1.4574 - (0.1123 * log(C)),0.25);
				%M1 = max(2.0238 - (0.2070 * log(C)),0.25);
				% ERA5 new aIdx=1, swIdx=0, bare ice
				M0 = max(1.4318 - (0.1055 * log(C)),0.25);
				M1 = max(2.0453 - (0.2137 * log(C)),0.25);
			end
		% ERA5 new aIdx=2, swIdx=1
		elseif aIdx<3 && swIdx>0
			M0 = max(1.7834 - (0.1409 * log(C)),0.25);
			M1 = max(1.9260 - (0.1527 * log(C)),0.25);
		end

		% ERA5 new aIdx=2, swIdx=0
		%elseif (aIdx==2)
		% From Kuipers Munneke
		%M0 = max(1.042 - (0.0916 * log(C)),0.25);
		%M1 = max(1.734 - (0.2039 * log(C)),0.25);
		%RACMO callibration, default (Gardner et al., 2023)
		M0 = max(1.2691 - (0.1184 * log(C)),0.25);
		M1 = max(1.9983 - (0.2511 * log(C)),0.25);
		c0 = M0*c0arth(idx);
		c1 = M1*c1arth(~idx);

end

% new snow density
d(idx) = d(idx) + (c0 .* (dIce - d(idx)) / 365 * dt);
d(~idx) = d(~idx) + (c1 .* (dIce - d(~idx)) / 365 * dt);

%disp((num2str(nanmean(c0 .* (dIce - d(idx)) / 365 * dt))))

% do not allow densities to exceed the density of ice
d(d > dIce-Ptol) = dIce;

% calculate new grid cell length
dz = mass_init ./ d;

