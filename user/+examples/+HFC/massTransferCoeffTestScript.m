% recreating data from gomez-coma (2014)
fFiberOD = 7.7E-4;  % [m]
fFiberID = 4.51E-4; % [m]
fFiberL = 0.295;    % [m]
fFiberCount = 11;
fContactArea = 4.6E-3;  % [m^2] effective inner membrane area
fPorosity = 0.3;
fPackingFactor = 0.04;

% pick data points at 30% water content in IL
fDynamicVisc = 38;  % cP
fILDensity = 1030;  % kg/m^3
fKinematicVisc = fDynamicVisc / fILDensity * 1E-3; % [m^2/s]

fGasFlowRate = 20 / 1e6 / 60;   % [m^3/s]
fCO2InletConc = 0.15;           % ratio
fTemperatre = 300;              % [K]
fPressure = 101325;             % [Pa]
R = 8.314;                      % [J/mol/K]


