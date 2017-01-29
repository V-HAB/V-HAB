function fDensity = calculateDensity(this, varargin)
%CALCULATEDENSITY Calculates the density of the matter in a phase or flow
%   Calculates the density of the matter inside a phase or the matter
%   flowing through the flow object. This is done by adding the single
%   substance densities at the current temperature and pressure and
%   weighing them with their mass fraction. Can use either a phase object
%   as input parameter or the phase type (sType) and the masses array
%   (afMass). Optionally temperature and partial pressures can be passed as
%   third and fourth parameters, respectively.
%
%   Examples: fDensity = calculateDensity(oFlow);
%             fDensity = calculateDensity(oPhase);
%             fDensity = calculateDensity(sType, afMass, fTemperature, afPartialPressures);
%
% calculateDensity returns
%  fDensitiy - density of matter in current state in kg/m^3

% Case one - just a phase or flow object provided
if length(varargin) == 1
    if ~isa(varargin{1}, 'matter.phase') && ~isa(varargin{1}, 'matter.flow')
        this.throw('calculateDensity', 'If only one param provided, has to be a matter.phase or matter.flow (derivative)');
    end
    
    % Initialize attributes from input object
    % Getting the phase type (gas, liquid, solid) depending on the object
    % type
    if isa(varargin{1}, 'matter.phase')
        sMatterState = varargin{1}.sType;
        oPhase = varargin{1};
    elseif isa(varargin{1}, 'matter.flow')
        sMatterState = varargin{1}.oBranch.getInEXME().oPhase.sType;
        oPhase = varargin{1}.oBranch.getInEXME().oPhase;
    end
    
    fTemperature = varargin{1}.fTemperature;
    
    if strcmp(sMatterState, 'gas')
        % If the matter state is gaseous and the pressure is not too high, 
        % we can use the idal gas law. This makes the calculation a lot
        % faster, since we can avoid the multiple findProperty() calls in
        % this function.
        if varargin{1}.fPressure < 5e5
            fDensity = (varargin{1}.fPressure * varargin{1}.fMolarMass) / (this.Const.fUniversalGas * varargin{1}.fTemperature);
            % We already have what we want, so no need to execute the rest
            % of this function.
            return;
        end
        
        [ afPartialPressures, ~ ] = this.calculatePartialPressures(varargin{1});
        
    elseif strcmp(sMatterState, 'liquid')
        % For liquids the density has to be calculated from the matter
        % table.
        afPartialPressures = ones(1, this.iSubstances) * varargin{1}.fPressure;
    elseif strcmp(sMatterState, 'mixture')
        % for mixtures the actual matter type is set by the user and
        % also differs for each substance. The partial pressure for a gas
        % mixture phase (e.g. gas that contains solids) has to be
        % calculated the same way as for a gas phase except for the
        % substances that are solid

        if isempty(oPhase.sPhaseType)
            afPartialPressures = ones(1,this.iSubstances) .* this.Standard.Pressure;
            aiPhase = this.determinePhase(oPhase.afMass, oPhase.fTemperature, ones(1,this.iSubstances) .* this.Standard.Pressure);
        else
            aiPhase = this.determinePhase(oPhase.afMass, oPhase.fTemperature, ones(1,this.iSubstances) .* oPhase.fPressure);
            if strcmp(oPhase.sPhaseType, 'gas')
                afMassGas = zeros(1,this.iSubstances);
                afMassGas(aiPhase ~= 1) = oPhase.afMass(aiPhase ~= 1);
                afPartialPressures = this.calculatePartialPressures('gas',afMassGas, oPhase.fPressure, oPhase.fTemperature);
                afPartialPressures(aiPhase == 1) = oPhase.fPressure;

                aiPhase = this.determinePhase(oPhase.afMass, oPhase.fTemperature, afPartialPressures);
                
                aiPhase = round(aiPhase,0);
            else
                afPartialPressures = ones(1,this.iSubstances) .* oPhase.fPressure;
            end
        end
    else
        
        if isa(varargin{1}, 'matter.phase')
            % Solid phases are easy again, we can just divide the mass by
            % the volume and we're done.
            fDensity = varargin{1}.fMass / varargin{1}.fVolume;
            return;
        else
            %TODO Implement something smart here.
            this.throw('calculateDensity', 'The calculation of solid flow densities has not yet been implemented.')
        end
    end
    
    if isempty(fTemperature) || isnan(fTemperature)
        fTemperature = this.Standard.Temperature; % std temperature (K)
    end
    
    arPartialMass = varargin{1}.arPartialMass;
    
    % in no mass given also no density possible
    if sum(arPartialMass) == 0
        fDensity = 0;
        return;
    end
    
else
    % This part is in case values directly passed to this function, rather
    % than a phase or flow object.
    sMatterState = varargin{1};
    afMass       = varargin{2};
    
    arPartialMass = afMass ./ sum(afMass);
    
    % if no mass given also no density possible
    if sum(afMass) == 0 || sum(isnan(afMass)) == length(afMass)
        fDensity = 0;
        return;
    end
    
    % if additional temperature and pressure given
    if nargin > 3
        fTemperature = varargin{3};
    else
        fTemperature = this.Standard.Temperature; % std temperature (K)
    end
    
    % Assume if vector with length > 1 -> partials, else total pressure
    if nargin > 4 && ~isempty(varargin{4}) && isvector(varargin{4}) && length(varargin{4}) > 1
        afPartialPressures = varargin{4};
    else
        fPressure = this.Standard.Pressure;
        
        if nargin > 4 && ~isempty(varargin{4}) && isvector(varargin{4}) && isscalar(varargin{4})
            fPressure = varargin{4};
        end
        
        if any(strcmp(sMatterState, {'gas'}))
            [ afPartialPressures, ~ ] = this.calculatePartialPressures(sMatterState, afMass, fPressure);
        else
            afPartialPressures = ones(1, this.iSubstances) * this.Standard.Pressure;
        end
    end
    
end

% Find the indices of all substances that are in the flow
aiIndices = find(arPartialMass > 0);

% Go through all substances that have mass and get the density of each. 
afRho = zeros(1, length(aiIndices));

csPhase = {'solid';'liquid';'gas';'supercritical'};
tiP2N.solid = 1;
tiP2N.liquid = 2;
tiP2N.gas = 3;
tiP2N.supercritical = 4;
if ~strcmp(sMatterState, 'mixture')
    aiPhase = tiP2N.(sMatterState)*ones(1,this.iSubstances);
end

% If determine phase yield anything besides integer this
% basically means a phase change is occuring at the moment.
% Currently this can only be covered by a simplified
% rounding operation
aiPhase = round(aiPhase);

for iI = 1:length(aiIndices)
    % Generating the paramter struct that findProperty() requires.
    tParameters = struct();
    tParameters.sSubstance = this.csSubstances{aiIndices(iI)};
    tParameters.sProperty = 'Density';
    tParameters.sFirstDepName = 'Temperature';
    tParameters.fFirstDepValue = fTemperature;
    tParameters.sPhaseType = csPhase{aiPhase(aiIndices(iI))};
    tParameters.sSecondDepName = 'Pressure';
    tParameters.fSecondDepValue = afPartialPressures(aiIndices(iI));
    tParameters.bUseIsobaricData = true;
    
    % Now we can call the findProperty() method.
    afRho(iI) = this.findProperty(tParameters);
end

% Sum up the densities multiplied by the partial masses to get the overall density.
fDensity = sum(afRho .* arPartialMass(aiIndices));

% If none of the substances has a valid density an error is thrown.
if fDensity < 0 || isnan(fDensity)
    this.throw('calculateDensity','Error in Density calculation!');
end

end

