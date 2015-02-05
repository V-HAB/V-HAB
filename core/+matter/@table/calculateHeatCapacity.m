function fHeatCapacity = calculateHeatCapacity(this, varargin)
%CALCULATEHEATCAPACITY Summary of this function goes here
% Calculates the total heat capacity by adding the single
% substance capacities weighted with their mass fraction. (Same
% as in calcMolMass) Can use either a phase object as input
% parameter, or the phase type (sType) and the masses array
% (afMass). Optially temperature and pressure can be passed as
% third and fourth parameters, respectively.
%
% calculateHeatCapacity returns
%  fHeatCapacity  - specific, isobaric heat capacity of mix in J/kgK?

% Case one - just a phase object provided
if length(varargin) == 1
    if ~isa(varargin{1}, 'matter.phase')
        this.throw('calculateHeatCapacity', 'If only one param provided, has to be a matter.phase (derivative)');
    end
    
    % initialise attributes from phase object
    sPhase  = varargin{1}.sType;
    afMass = varargin{1}.afMass;
    fT = varargin{1}.fTemp;
    fP = varargin{1}.fPressure;
    if isempty(fP); fP = this.Standard.Pressure; end; % std pressure (Pa)
    
    % if no mass given also no heatcapacity possible
    if varargin{1}.fMass == 0 || sum(isnan(afMass)) == length(afMass)
        fHeatCapacity = 0;
        return;
    end
    
else
    sPhase  = varargin{1};
    afMass = varargin{2};
    
    % if no mass given also no heatcapacity possible
    if sum(afMass) == 0 || sum(isnan(afMass)) == length(afMass)
        fHeatCapacity = 0;
        return;
    end
    
    % if additional temperature and pressure given
    if nargin > 2
        fT = varargin{3};
        fP = varargin{4};
    else
        fT = this.Standard.Temperature; % std temperature (K)
        fP = this.Standard.Pressure;    % std pressure (Pa)
    end
    
    if nargin > 4
        sPhase = varargin{5};
    end
    
end


% look which substances have mass so heatcapacity can calculated
aiIndices = find(afMass>0);

% go through all substances that have mass and get the heatcapacity of each. then add this to the
% rest
afCp = zeros(length(aiIndices), 1);      % Initialize an arry filled with zeros

for iI=1:length(find(afMass>0))
    afCp(iI) = this.findProperty(this.csSubstances{aiIndices(iI)}, 'Heat Capacity', 'Temperature', fT, 'Pressure', fP, sPhase);
end

% Multiply the individual heat capacities with the partial masses
fHeatCapacity = afMass(aiIndices) / sum(afMass) * afCp;

% If none of the substances has a valid heatcapacity an error is thrown.
if (fHeatCapacity < 0 || isnan(fHeatCapacity)) && ~(sum(afMass) == 0)
    this.throw('calculateHeatCapacity','Error in HeatCapacity calculation!');
end
end