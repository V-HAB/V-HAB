function fDensity = calculateDensity(this, varargin)
%CALCULATEDENSITY Calculates the density of the matter in a phase or flow
%   Calculates the density of the matter inside a phase or the matter
%   flowing through the flow object. This is done by adding the single
%   substance densities at the current temperature and pressure and
%   weighing them with their mass fraction. Can use either a phase object
%   as input parameter or the phase type (sType) and the masses array
%   (afMass). Optionally temperature and pressure can be passed as third
%   and fourth parameters, respectively.
%
% calculateDensity returns
%  fDensitiy - density of matter in current state in kg/m^3

fDensity = -1;

% Case one - just a phase object provided
if length(varargin) == 1
    if ~isa(varargin{1}, 'matter.phase') || ~isa(varargin{1}, 'matter.flow')
        this.throw('fHeatCapacity', 'If only one param provided, has to be a matter.phase or matter.flow (derivative)');
    end
    
    if isa(varargin{1}, 'matter.phase')
        % initialize attributes from phase object
        sPhase        = varargin{1}.sType;
        afMass        = varargin{1}.afMass;
        fTemperature  = varargin{1}.fTemp;
        fPressure     = varargin{1}.fPressure;
        
        
        % if no mass given also no density possible
        if varargin{1}.fMass == 0 || sum(isnan(afMass)) == length(afMass)
            fDensity = 0;
            return;
        end
    elseif isa(varargin{1}, 'matter.flow')
        
    end
    
else
    sPhase  = varargin{1};
    afMass  = varargin{2};
    
    % if no mass given also no heatcapacity possible
    if sum(afMass) == 0 || sum(isnan(afMass)) == length(afMass)
        fDensity = 0;
        return;
    end
    
    % if additional temperature and pressure given
    if nargin > 2
        fTemperature = varargin{3};
        fPressure    = varargin{4};
    end
end

if isempty(fPressure);    fPressure    = this.Standard.Pressure;    end; % std pressure (Pa)
if isempty(fTemperature); fTemperature = this.Standard.Temperature; end; % std temperature (K)
        

% look which substances have mass so heatcapacity can calculated
aiIndexes = find(afMass>0);
% go through all substances that have mass and calculate the heatcapacity of each. then add this to the
% rest
for i=1:length(find(afMass>0))
    fRho = this.FindProperty(this.csSubstances{aiIndexes(i)}, 'Heat Capacity', 'Temperature', fTemperature, 'Pressure', fPressure, sPhase);
    
    fDensity = fDensity + afMass(aiIndexes(i)) ./ sum(afMass) * fRho;
end

% If none of the substances has a valid heatcapacity an error
% is thrown.
if (fDensity < 0 || isnan(fDensity)) && sum(afMass) == 0
    this.throw('calculateHeatCapacity','Error in HeatCapacity calculation!');
end

end

