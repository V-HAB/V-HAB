function [fTemperature, arPartialMass, csPhase, aiPhase, aiIndices, afPartialPressures, tbReference, sMatterState, bUseIsobaricData] = getNecessaryParameters(this, varargin)
% Case one - just a phase or flow object provided
tbReference.bPhase = false;
tbReference.bFlow = false;
tbReference.bNone = false;

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
        tbReference.bPhase = true;
        
        if varargin{1}.fMass == 0
            arPartialMass = zeros(1, this.iSubstances);
        else
            afMass = this.resolveCompoundMass(varargin{1}.afMass, varargin{1}.arCompoundMass);
            arPartialMass = afMass / varargin{1}.fMass;
        end
    elseif isa(varargin{1}, 'matter.flow')
        sMatterState = varargin{1}.oBranch.getInEXME().oPhase.sType;
        oPhase = varargin{1}.oBranch.getInEXME().oPhase;
        tbReference.bFlow = true;
        
        % For flows not partial masses but partial mass ratios are stored
        arPartialMass = this.resolveCompoundMass(varargin{1}.arPartialMass, varargin{1}.arCompoundMass);
    end
    
    fTemperature = varargin{1}.fTemperature;
    
    fPressure = varargin{1}.fPressure;
    
    if strcmp(sMatterState, 'gas')
        
        afPartialPressures = this.calculatePartialPressures(varargin{1});
        
    elseif strcmp(sMatterState, 'liquid')
        % If the pressure of the flow is zero, as would happen
        % during initialization, we use the pressure of the phase. 
        if fPressure == 0
            afPartialPressures = ones(1, this.iSubstances) * oPhase.fPressure;
        else
            afPartialPressures = ones(1, this.iSubstances) * fPressure;
        end
    elseif strcmp(sMatterState, 'mixture')
        % for mixtures the actual matter type is set by the user and
        % also differs for each substance. The partial pressure for a gas
        % mixture phase (e.g. gas that contains solids) has to be
        % calculated the same way as for a gas phase except for the
        % substances that are solid

        if isempty(oPhase.sPhaseType)
            afPartialPressures = ones(1,this.iSubstances) .* this.Standard.Pressure;
            aiPhase = this.determinePhase(arPartialMass, fTemperature, ones(1,this.iSubstances) .* this.Standard.Pressure);
        else
            aiPhase = this.determinePhase(arPartialMass, fTemperature, ones(1,this.iSubstances) .* fPressure);
            if strcmp(oPhase.sPhaseType, 'gas')
                afMassGas = zeros(1,this.iSubstances);
                afMassGas(aiPhase ~= 1) = oPhase.afMass(aiPhase ~= 1);
                afPartialPressures = this.calculatePartialPressures('gas',afMassGas, fPressure, fTemperature);
                afPartialPressures(aiPhase == 1) = fPressure;

                aiPhase = this.determinePhase(arPartialMass, fTemperature, afPartialPressures);
            else
                afPartialPressures = ones(1,this.iSubstances) .* fPressure;
            end
        end
    else
        % For Solids we also calculate matter properties based on the
        % overall pressure
        if fPressure == 0
            afPartialPressures = ones(1, this.iSubstances) * oPhase.fPressure;
        else
            afPartialPressures = ones(1, this.iSubstances) * fPressure;
        end
    end
    
    if isempty(fTemperature) || isnan(fTemperature)
        fTemperature = this.Standard.Temperature; % std temperature (K)
    end
    
    % We always use isobaric data. If you wish to use isochoric data, you
    % need to pass in the matter parameters manually and include as the
    % final barameter a false boolean. 
    bUseIsobaricData = true;
    
else
    % This part is in case values directly passed to this function, rather
    % than a phase or flow object.
    sMatterState = varargin{1};
    xfMass       = varargin{2};
    tbReference.bNone = true;
    
    if isstruct(xfMass)
        tfMass = xfMass;
        afMass = zeros(1, this.iSubstances);
        csSubstances = fieldnames(tfMass);
        for iSubstance = 1:length(csSubstances)
            afMass(this.tiN2I.(csSubstances{iSubstance})) = tfMass.(csSubstances{iSubstance});
        end
    else
        afMass = xfMass;
    end
    if sum(afMass) == 0
        arPartialMass = zeros(1, this.iSubstances);
    else
        arPartialMass = afMass ./ sum(afMass);
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
            afPartialPressures = this.calculatePartialPressures(sMatterState, afMass, fPressure, fTemperature);
        else
            afPartialPressures = ones(1, this.iSubstances) * fPressure;
        end
    end
    
    % Isobar or isochor?
    if nargin > 5 && varargin{5} == true
        bUseIsobaricData = true;
    else
        bUseIsobaricData = false;
    end
    
end

% Find the indices of all substances that are present and have a
% significant impact on the matter property (more than one promille)
aiIndices = find(arPartialMass > 0.001);

csPhase = {'solid';'liquid';'gas';'supercritical'};
tiP2N.solid = 1;
tiP2N.liquid = 2;
tiP2N.gas = 3;
tiP2N.supercritical = 4;
if ~strcmp(sMatterState, 'mixture')
    aiPhase = tiP2N.(sMatterState)*ones(1,this.iSubstances);
elseif length(varargin) ~= 1
    aiPhase = this.determinePhase(arPartialMass, fTemperature, afPartialPressures);
end

end