function fPressure = calculatePressure(this, varargin) %sMatterState, afMasses, fTemperature, fPressure)
% TO DO: Add description, also give partial pressures as output?

iNumArgs = length(varargin); % |iNumArgs == nargin - 1|!?

% Handle two variants of calling this method: With an object, where the
% necessary data can be retrieved from, or the data itself.
if iNumArgs == 1 %nargin < 3
    % First case: Just a phase or flow object is provided.
    %TODO: Delete this part and put it into the corresponding classes
    %      instead (the matter table should not know about other objects).
    
    oMatterRef = varargin{1};
    
    % Get data from object: The state of matter (gas, liquid, solid)
    % and |afMasses| array, depending on the object type.
    if isa(oMatterRef, 'matter.phase')
        
        sMatterState = oMatterRef.sType;
        arPartialMass = oMatterRef.arPartialMass;
        oPhase = oMatterRef;
        afMass = oPhase.afMass;
        fCurrentPressure = oPhase.fPressure;
        
    elseif isa(oMatterRef, 'matter.procs.p2p')
        sMatterState = oMatterRef.sType;
        arPartialMass = oMatterRef.arPartialMass;
        oPhase = oMatterRef.getInEXME().oPhase;
        afMass = oPhase.afMass;
        fCurrentPressure = oPhase.fPressure;
        
    elseif isa(oMatterRef, 'matter.flow')
        sMatterState = oMatterRef.oBranch.getInEXME().oPhase.sType;
        arPartialMass = oMatterRef.arPartialMass;
        if oMatterRef.fFlowRate >= 0
            oPhase = oMatterRef.oBranch.coExmes{1,1}.oPhase;
        else
            oPhase = oMatterRef.oBranch.coExmes{2,1}.oPhase;
        end
        afMass = oPhase.afMass;
        fCurrentPressure = oPhase.fPressure;
    else
        this.throw('calculateHeatCapacity', 'Single parameter must be of type |matter.phase| or |matter.flow|.');
    end
    
    % Get data from object: Temperature and pressure.
    fTemperature = oMatterRef.fTemperature;
    fDensity = oMatterRef.fDensity;
    if isempty(fTemperature) || isnan(fTemperature)
        fTemperature = this.Standard.Temperature; % std temperature (K)
    end
    
    bUseIsobaricData   = true;
    
else
    % Second case: Data is provided directly.
    
    sMatterState  = varargin{1}; % solid, liquid, or gas
    afMass      = varargin{2}; % mass per substance (array)
    arPartialMass = afMass./(sum(afMass));
    
    % Get temperature and pressure from arguments, otherwise use
    % standard data.
    if iNumArgs > 2
        fTemperature = varargin{3};
    else
        % Standard temperature in [K]
        fTemperature = this.Standard.Temperature;
    end
    
    if iNumArgs > 3
        fDensity    = varargin{4};
    else
        % Standard pressure in [Pa]
        fDensity = this.Standard.Density;
    end
    if iNumArgs > 4
        fCurrentPressure    = varargin{5};
    else
        % Standard pressure in [Pa]
        fCurrentPressure = this.Standard.Pressure;
    end
    
    if iNumArgs > 5
        bUseIsobaricData   = varargin{6};
    else
        bUseIsobaricData   = true;
    end
    
    % If there is no temperature given, but pressure, set temperature to
    % standard temperature in [K]
    if isempty(fTemperature); fTemperature = this.Standard.Temperature; end;
end

% If no mass is given the heat capacity will be zero, so no need to do the
% rest of the calculation.
if sum(arPartialMass) == 0
    fPressure = 0;
    return;
end

% Make sure there is no NaN in the mass vector.
assert(~any(isnan(arPartialMass)), 'Invalid entries in mass vector.');

% Find substances with a mass bigger than zero and count the results.
% This helps in getting only the needed data from the matter table.
aiIndices   = find(arPartialMass > 0);

% TO DO: write determinePhase function to work with the density as well as
% the pressure and replace the fCurrentPressure property in this function
% with the density

csPhase = {'solid';'liquid';'gas';'supercritical'};

% One of the most important parts to correctly calculate the pressure is to
% use the correct partial densities.
switch sMatterState
    case 'solid'
        
        error('In V-HAB solids do not have a pressure')
    case 'liquid'
        % for liquids the partial density of each substance can not be
        % calculated as simply as for gases where each gas can be assumed
        % to occupy the complete volume by itself. Instead of each
        % component of the liquid having an individual partial pressure it
        % is more accurate to assume that all substance inside the liquid
        % have the same pressure. However if the same principle would be
        % applied to the density it would not result in correct values
        % since e.g. water has a density of ~1000 kg/m³ while Isopentan has
        % a density of 616 kg/m². If the two would form a mixture with very
        % little water and then using the overall density to calculate the
        % pressure would result in the water changing its phase according
        % to this calculation.
        % Instead it is more accurate to say that each liquid occupies a
        % part volume and has a partial density that fits the pressure and
        % temperature for a pure liquid of this substance. However that
        % makes the calculation of the pressure for liquids difficult
        % because the pressure is required in order to calculate the
        % density. If now the density is required to calculate the pressure
        % as well this could only be solved iterativly with a huge impact
        % on the computation time. 
        % Furthermore for mixtures of several liquids the calculation of
        % the partial volumes would require yet another iteration to ensure
        % that each liquid of the mixture actually reaches the same
        % pressure. 
        %
        % Brainstorming: What can we easily calculate?
        % - Overall Density
        % - Overall Temperature
        % - Overall Volume
        % - Overall Mass
        % - Partial Masses
        % - Mass Ratios
        % 
        % And how can we use that to calculate the pressure of a liquid
        % mixture? (note pure liquids are simple ;))
        %
        % Also aside from liquid + liquid mixtures it is also necessary to
        % implement the mixture of liquid+solid+gas. For liquid + solid the
        % same approach as for solid + gas can be used! For liquid + gas
        % the approach would be to assume that the gas has the same
        % pressure as the liquid and it is ignored during the pressure
        % calculation
        %
        % Liquid + Liquid mixture calculation approach:
        % 
        %
        %
        
        error('Not yet implemented sorry')
    case 'gas'
        % gases behave as if each component of the gas mixture is alone in
        % the total gas volume and therefore the partial density is the
        % mass ratio times the total density.
        afPartialDensity = arPartialMass.*fDensity;
        
        aiPhase = this.determinePhase(afMass, fTemperature, ones(1,this.iSubstances) .* fCurrentPressure);
        aiLiquidIndices = find(aiPhase == 2,1);
            
    case 'mixture'
        switch oPhase.sPhaseType
            case 'solid'
                error('In V-HAB solids do not have a pressure')
            case 'liquid'
                error('Not yet implemented sorry')
            case 'gas'
            aiPhase = this.determinePhase(afMass, fTemperature, ones(1,this.iSubstances) .* fCurrentPressure);
            % for the case of a gas mixture with solid components the solid
            % substances have to be subtracted from the volume to get the
            % remaining volume for the gases. Liquids are assumed to be
            % gases in this case (like water vapor in the air). In order to
            % achieve this it is necessary to first calculate the density
            % for the solid components.
            aiSolidIndices = find(aiPhase == 1,1);
            aiLiquidIndices = find(aiPhase == 2,1);
            if ~isempty(aiSolidIndices)
                
                afMassSolids = afMass;
                afMassSolids(aiPhase ~= 1)= 0;
                fDensitySolids = this.calculateDensity('solid',afMassSolids, fTemperature, fCurrentPressure);

                fVolumeGas = (oPhase.fVolume - (sum(afMassSolids) / fDensitySolids));
                fDensityGas = sum(afMass(aiPhase~=1))/fVolumeGas;
                afPartialDensity = arPartialMass.*fDensityGas;
            
                afPartialDensity(aiSolidIndices) = 0;

                aiIndices(aiIndices == aiSolidIndices) = [];
                
            else
                afPartialDensity = arPartialMass.*fDensity;
            end
            aiPhase = 3*ones(1,this.iSubstances);
        end
end

iNumIndices = length(aiIndices);

% Initialize a new array filled with zeros. Then iterate through all
% indexed substances and get their specific heat capacity.
afPP = zeros(iNumIndices, 1);

for iI = 1:iNumIndices
    % Creating the input struct for the findProperty() method
    tParameters = struct();
    tParameters.sSubstance = this.csSubstances{aiIndices(iI)};
    tParameters.sProperty = 'Pressure';
    tParameters.sFirstDepName = 'Temperature';
    tParameters.fFirstDepValue = fTemperature;
    tParameters.sPhaseType = csPhase{aiPhase(aiIndices(iI))};
    tParameters.sSecondDepName = 'Density';
    tParameters.fSecondDepValue = afPartialDensity(aiIndices(iI));
    tParameters.bUseIsobaricData = bUseIsobaricData;
    
    % Now we can call the findProperty() method.
    afPP(iI) = this.findProperty(tParameters);
end


if ~isempty(aiLiquidIndices)
% For liquids in gases it is necessary to calculate the
% vapor pressure and check if actually all of the liquid is
% vapor or if some is liquid. For this purpose the vapor
% pressure is calculated here and then compared to the
% calculated partial pressure assuming that all of the liquid
% is vapor. If the partial pressure calculated under this
% assumption is higher than the vapor pressure some of the
% water has to be liquid.
    csLiquids = this.csSubstances(aiLiquidIndices);
    for iK = 1:length(csLiquids)
        tVaporPressure.(csLiquids{iK}) = this.calculateVaporPressure(fTemperature, csLiquids{iK});
    end
    afLiquidPartialPressures = afPP(aiIndices == aiLiquidIndices);
    for iK = 1:length(afLiquidPartialPressures)
        if afLiquidPartialPressures(iK) > tVaporPressure.(csLiquids{iK})
            % in this case some of the normally liquid substance in the gas
            % phase is actually liquid and the partial pressure for it is
            % exactly the vapor pressure
            afPP(aiIndices == aiLiquidIndices(iK)) = tVaporPressure.(csLiquids{iK});
            % the available volume for the gas in this case also would have
            % to be reduced by the volume the actually liquid substance
            % occupies but that would require an actual calculation how
            % much of the substance is liquid and how much is vapor. For
            % this it would be necessary to calculate the vapor density at
            % the given vapor pressure and multiply it with the gas volume
            % resulting the vapor mass for the substance. That could then
            % be subtracted from the overall substance mass to gain the
            % liquid mass of the substance. Then the density for the liquid
            % at the total pressure and temperature would have to be
            % calculated in order to obtain the volume the liquid occupies.
            % This volume could then be subtracted from the gas volume to
            % gain the actual gas volume which then could be used to
            % calculate the new partial densities for the substances. Now
            % the whole find property calculation would have to be redone
            % in order to calculate the correct partial pressures. For the
            % precise solution this would even have to be iterated.
            %
            % To make a long story short, the assumption for this case
            % (since the actual calculation would be overkill) is that the
            % liquid volume is much smaller than the gas volume and can be
            % neglected.
        end
    end
end

% Make sure there is no NaN in the specific heat capacity vector.
assert(~any(isnan(afPP)), 'Invalid entries in partial pressure vector.');

% Make sure no negative partial pressure were calculated
assert(~any(afPP < 0), 'Invalid entries in partial pressure vector.');
%DEBUG
assert(isequal(size(afPP), size(arPartialMass(aiIndices)')), 'Vectors must be of same length but one transposed.');

% Multiply the specific heat capacities with the mass fractions. The
% result of the matrix multiplication is the specific heat capacity of
% the mixture.
fPressure = sum(afPP);

% Make sure the heat capacity value is valid.
assert(~isnan(fPressure) && fTemperature >= 0, ...
    'Invalid pressure: %f', fTemperature);

% "Most physical systems exhibit a positive heat capacity. However,
% there are some systems for which the heat capacity is negative. These
% are inhomogeneous systems which do not meet the strict definition of
% thermodynamic equilibrium.
% A more extreme version of this occurs with black holes. According to
% black hole thermodynamics, the more mass and energy a black hole
% absorbs, the colder it becomes. In contrast, if it is a net emitter
% of energy, through Hawking radiation, it will become hotter and
% hotter until it boils away."
%     -- http://en.wikipedia.org/wiki/Heat_capacity
%        (Retrieved: 2015-05-27 23:48 CEST)
end
