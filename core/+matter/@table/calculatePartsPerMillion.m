function afPartsPerMillion = calculatePartsPerMillion(this, varargin)
%calculatePartsPerMillion Calculates parts per million of gas phases and
%flows
%   Calculates the parts per million for all substances in a gas phase, gas
%   flow or a body of matter in a gaseous state. Therfore input arguments
%   have to be either a matter.phase object, a matter.flow object or matter
%   data formatted and in the order shown below. 
%
%   calculatePartsPerMillion returns
%       afPartsPerMillion - An array of the parts per million in ppm

% Case one - just a phase or flow object provided
if length(varargin) == 1
    bIsaMatterPhase = strcmp(varargin{1}.sObjectType, 'phase');
    bIsaMatterFlow  = strcmp(varargin{1}.sObjectType, 'flow');
    
    if ~bIsaMatterPhase && ~bIsaMatterFlow
        this.throw('calculatePartialPressures', 'If only one param provided, has to be a matter.phase or matter.flow (derivative)');
    end
    
    % initialize attributes from input object
    % Getting the phase type (gas, liquid, solid) depending on the object
    % type, also setting the afMass array. 
    if bIsaMatterPhase
        afMass = varargin{1}.afMass;
    elseif bIsaMatterFlow
        afMass = varargin{1}.arPartialMass;
    end
    
    if bIsaMatterPhase
        fPressure = varargin{1}.fMass * varargin{1}.fMassToPressure;
    else
        fPressure = varargin{1}.fPressure;
    end
    
    if isempty(fPressure) || isnan(fPressure)
        fPressure = this.Standard.Pressure; % std pressure (Pa)
    end       
    
    if fPressure == 0
        afPartsPerMillion = zeros(this.iSubstances,1);
    else
        try
            afPartsPerMillion = (afMass .* varargin{1}.fMolarMass) ./ (this.afMolarMass .* varargin{1}.fMass) * 1e6;
        catch
            afPartsPerMillion = (afMass .* this.calculateMolarMass(afMass)) ./ (this.afMolarMass .* sum(afMass)) * 1e6;
        end
    end
    
else
    % Case two - matter data given. Needs to be in the following format and order:
    % phase type (string)
    % substance masses (array of floats)
    % pressure (float)
    
    % PhaseType (solid, liquid or gas)
    sPhase  = varargin{1};
    afMass  = varargin{2};
    
    % If pressure is given use it, otherwise use standard pressure
    if length(varargin) > 2
        fPressure = varargin{3};
    else
        fPressure = this.Standard.Pressure;       % std pressure (Pa)
    end

    % Make sure we have matter in a gaseous state
    if ~strcmp(sPhase, 'gas')
        this.throw('calculatePartialPressures', 'Partial pressures can only be calculated for gases!');
    end

    if fPressure == 0
        afPartsPerMillion = zeros(this.iSubstances,1);
        return;
    end

    afPartsPerMillion = (afMass .* this.calculateMolarMass(afMass)) ./ (this.afMolarMass .* sum(afMass)) * 1e6;
end

end


