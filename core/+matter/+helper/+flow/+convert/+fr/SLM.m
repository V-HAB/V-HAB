function fLiterPerMin = SLM(oFlow, bSTP)
%SLM Convert fFlowRate on matter.flow to Standard Liters per Minute
%   Uses the molecular mass (etc?) to convert to SLM. See
%   http://en.wikipedia.org/wiki/Standard_Liter_Per_Minute
%   http://www.wolframalpha.com/input/?i=SLPM
%
%   Assuming standard conditions (STP), see
%   http://en.wikipedia.org/wiki/Standard_temperature_and_pressure
%   http://www.wolframalpha.com/input/?i=STP
%   There are several definitions (0C, 1bar; 15C, 1.01325bar; ...)
%   Wolfram Alpha / Wikipedia both mention 293.15K/101325Pa -> use that
%
%SLM parameters:
%   - oFlow     Flow object
%   - bSTP      Get temperature and pressure from flow, or use STP values?
%               NOTE: default is TRUE!

if nargin < 2, bSTP = true; end;

if ~isa(oFlow, 'matter.flow')
    % Has to be an instance of matter.flow OR a struct containing all
    % necessary information!
    if ~isstruct(oFlow)
        error('First param either has to be a matter.flow, or a struct!');
    end
    
    % Flow rate, molecular mass have to be there!
    if ~isfield(oFlow, 'fFlowRate') || ~isfield(oFlow, 'fMolMass')
        error('Provided struct doesn''t contain fFlowRate || fMolMass');
    end
    
    % If NOT standard temp, pressure, need those values as well!
    if ~bSTP
        if ~isfield(oFlow, 'fTemperature') || ~isfield(oFlow, 'fPressure')
            error('Standard temperature and pressure was false, but provided struct doesn''t contain fTemperature || fPressure');
        end
    end
end

% Get flow rate [kg/s]
fFlowRate = oFlow.fFlowRate;

% Convert to /min
fFlowRate = fFlowRate * 60;

% Temperature and pressure ...
if bSTP
    % ... from standard conditions
    fTemperature  = 273.15 + 20; % 20 deg C
    fPressure     = 101325;
else
    % ... from flow
    fTemperature  = oFlow.fTemperature;
    fPressure     = oFlow.fPressure;
end

% Flow rate is now kg/min, need to convert kg to Liters --> use ideal gas
% equation
%TODO if > 5 - 10bar, other equation?
% From p * V = n * R * T = m / M * R * T
%          V = m / M * R * T / p
% Note: the molecular mass on oFlow is in [g/mol], therefore / 1000
%       result of eq above is m^3, so * 1000 for liters!

fLiterPerMin = (fFlowRate / (oFlow.fMolMass / 1000) * ...
               matter.table.C.R_m * fTemperature / fPressure) * 1000;

end

