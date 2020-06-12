classdef flow < base
    %FLOW A class describing the flow of matter. It is used to describe a
    % homogenous flow of matter at an interface between other components of
    % the simulation.
    
    properties (SetAccess = protected, GetAccess = public)
        % Flow rate, pressure and temperature of the matter stream
        fFlowRate    = 0;   % [kg/s]
        
        % Pressure of this flow object
        fPressure    = 0;  % [Pa]
        
        % Temperature of this flow object
        fTemperature = 293;   % [K]
        
        fSpecificHeatCapacity = 0;       % [J/K/kg]
        fMolarMass            = 0;       % [kg/mol]
        
        % Only recalculated when setData was executed and requested again!
        % Density of the matter of the flow in kg/m�
        fDensity;           % [kg/m^3]
        % Dynamic Viscosity of the matter of the flow in Pa/s
        fDynamicViscosity;  % [Pa/s]
        
        % Partial masses in percent (ratio) in indexed vector (use oMT to
        % translate, e.g. this.oMT.tiN2I)
        arPartialMass;
        
        % To model masses consisting of more than one substance, compound
        % masses can be defined. If these are transported through flows,
        % their current composition is stored in this struct
        arCompoundMass;
        
        % Reference to the matter table
        oMT;
        
        % Reference to the timer
        oTimer;
        
        % Branch the flow belongs to
        oBranch;
        
        % The store the flow belongs to if it is used as the parent class
        % of a p2p processor.
        oStore;
        
        % Diameter
        fDiameter = 0;
        
        % References to the processors connected to the flow (exme || f2f)
        oIn;
        oOut;
        
        % Sealed?
        bSealed = false;
        
        % Interface flow? If yes, can be reconnected even after seal, also
        % the remove callback can be executed for in methods other then
        % delete
        bInterface = false;
        
        tfPropertiesAtLastMassPropertySet;
    
        % In order to remove the need for numerous calls to isa(),
        % especially in the matter table, this property can be used to see
        % if an object is derived from this class. 
        sObjectType = 'flow';
    end
    
    properties (Dependent)
        % Partial pressures of the matter of the flow
        afPartialPressure;  % [Pa]
    end
    
    properties (SetAccess = private, GetAccess = private)
        % A struct containing the necessary function handles to later on
        % remove the corresponding flows from the F2F
        thRemoveCBs = struct();
    end
    
    methods
        function this = flow(oCreator)
            %% flow class constructor
            % creates a new matter flow object
            if nargin == 1
                % Setting the matter table
                this.oMT    = oCreator.oMT;
                this.oTimer = oCreator.oTimer;
                
                % The flow class can either be used on its own, or as a parent
                % class for a p2p processor. In the latter case, the flow
                % belongs to a store instead of a branch.
                
                if isa(oCreator,'matter.branch')
                    this.oBranch = oCreator;
                elseif isa(oCreator,'matter.store')
                    this.oStore  = oCreator;
                end
                
                % Initialize the mass fractions array with zeros.
                this.arPartialMass  = zeros(1, this.oMT.iSubstances);
                this.arCompoundMass = zeros(this.oMT.iSubstances, this.oMT.iSubstances);
                
                this.tfPropertiesAtLastMassPropertySet.fTemperature = -1;
                this.tfPropertiesAtLastMassPropertySet.fPressure    = -1;
                this.tfPropertiesAtLastMassPropertySet.arPartials   = this.arPartialMass;
            end
            
            
        end
        
        function [ setData, hRemoveIfProc ] = seal(this, bIf, oBranch)
            %% seal flow
            % seals the flow object and provides the setData function for
            % this flow as function handle output. Also provides a function
            % handle to remove an interface processor
            %
            % Required Inputs
            % bIf:      Flag to identify this flow as an interface flow
            % oBranch:  Object reference to the branch in which the flow is
            %           located when it is sealed
            %
            % Outputs:
            % setData:          Function handle to set the matter data
            %                   (e.g. pressure) of the flow object
            % hRemoveIfProc:    Function handle to remove the flow if it is
            %                   an interface flow
            if this.bSealed
                this.throw('seal', 'Already sealed!');
            end
            
            hRemoveIfProc = [];
            setData = @(oThis, varargin) oThis.setData(varargin{:});
            
            this.bSealed = true;
            
            % Param from parent required for bIf?
            if ~isempty(this.oIn) && isempty(this.oOut) && (nargin > 1) && bIf
                this.bInterface = true;
                hRemoveIfProc   = @this.removeIfProc;
            end
            
            if nargin > 2
                this.oBranch = oBranch; 
            end

            % If this is not an interface flow, we initialize the matter
            % properties. 
            if (nargin < 2) || ~bIf

                % Initialize the matter property attributes, get them from
                % the phase with the higher mass. If this flow is part of
                % an interface branch, one of the phases might not exist.
                % So we take a look at the branch and decide which phase we
                % want to use for initialization.
                if any(this.oBranch.abIf)
                    oPhase = this.oBranch.coExmes{~this.oBranch.abIf}.oPhase;
                else
                    aoPhases = [ this.oBranch.coExmes{1}.oPhase, this.oBranch.coExmes{2}.oPhase ];
                    if aoPhases(1).fMass >= aoPhases(2).fMass
                        oPhase = aoPhases(1);
                    else
                        oPhase = aoPhases(2);
                    end
                end
                
                % This is likely to be overwritten by the assigned solver
                % in the first, initializion step (time < 0)
                if oPhase.fMass ~= 0
                    this.arPartialMass  = oPhase.arPartialMass;
                    this.fMolarMass     = oPhase.fMolarMass;
                    this.arCompoundMass = oPhase.arCompoundMass;
                end

            end
        end
        
        
        function remove(this)
            %% remove flow
            %
            % Removes the flow from the f2f/exme objects to which it is
            % connect and empties the oIn and oOut properties
            
            if ~isempty(this.oIn)  && isvalid(this.oIn),  this.thRemoveCBs.in(); end
            if ~isempty(this.oOut) && isvalid(this.oOut), this.thRemoveCBs.out(); end
            
            this.oIn = [];
            this.oOut = [];
        end
        
        function fDensity = getDensity(this)
            %% getDensity
            % the Density property is set to empty when the setData
            % function of the flow is executed (when the matter properties
            % of the flow changed). It is then received through this
            % function, which only recalculates it using the matter table
            % if that was not yet done before
            %
            % Outputs:
            % fDensity: Density of the matter of the flow in kg/m^3
            if isempty(this.fDensity)
                this.fDensity = this.oMT.calculateDensity(this);
            end
            
            fDensity = this.fDensity;
        end
        
        
        function fDynamicViscosity = getDynamicViscosity(this)
            %% getDynamicViscosity
            % the Dynamic Viscosity property is set to empty when the
            % setData function of the flow is executed (when the matter
            % properties of the flow changed). It is then received through
            % this function, which only recalculates it using the matter
            % table if that was not yet done before
            %
            % Outputs:
            % fDynamicViscosity: Dynamic Viscosity of the matter of the
            %                    flow in Pa/s
            if isempty(this.fDynamicViscosity)
                this.fDynamicViscosity = this.oMT.calculateDynamicViscosity(this);
            end
            
            fDynamicViscosity = this.fDynamicViscosity;
        end
        
        function afPartialPressure = get.afPartialPressure(this)
            afPartialPressure = this.oMT.calculatePartialPressures(this);
        end
    end
    
    
    
    
    %% Sealed to ensure flow/f2f proc behaviour
    methods (Sealed = true)
        
        function [ iSign ] = addProc(this, oProc, removeCallBack)
            %% addProc
            % Adds the provided processor (has to be or derive from either
            % matter.procs.f2f or matter.procs.exme). If *oIn* is empty,
            % the proc is written on that attribute, and -1 is returned.
            % Otherwise if oIn is not empty but oOut is the proc is written
            % to the oOut attribut and 1 is returned for iSign.
            %
            % Required Inputs:
            % oProc:            f2f/exme to which the flow should be added
            % removeCallBack:   function handle which can be used to remove
            %                   the flow from the f2f/exme
            %
            % Outputs:
            % iSign:    is -1 if the f2f/exme is written to oIn and 1 if it
            %           is written to oOut
            
            % Proc of right type?
            if ~isa(oProc, 'matter.procs.f2f') && ~isa(oProc, 'matter.procs.exme')
                this.throw('addProc', 'Provided proc is not a or derives from either matter.procs.f2f or matter.procs.exme!');
                
            % Ensures that flow can only be added through proc addFlow
            % methods, since aoFlows attribute has SetAccess private!
            elseif isa(oProc, 'matter.procs.f2f')
                if ~any(oProc.aoFlows == this)
                    this.throw('addProc', 'Object processor aoFlows property is not the same as this one - use processor''s addFlow method!');
                end
            elseif isa(oProc, 'matter.procs.exme')
                if ~any(oProc.oFlow == this)
                    this.throw('addProc', 'Object in exme oFlow property is not the same as this one - use exme''s addFlow method!');
                end
            
            % If sealed, can only do if also an interface. Additional check
            % for oIn just to make sure only oOut can be reconnected.
            elseif this.bSealed && (~this.bInterface || isempty(this.oIn))
                this.throw('addProc', 'Can''t create branches any more, sealed.');
            
            end
            
            iSign = 0;
            
            if isempty(this.oIn)
                this.oIn = oProc;
                iSign    = -1;
                
                this.thRemoveCBs.in = removeCallBack;
                
            elseif isempty(this.oOut)
                this.oOut = oProc;
                iSign     = 1;
                
                this.thRemoveCBs.out = removeCallBack;
                
            else
                this.throw('addProc', 'Both oIn and oOut are already set');
            end
        end
    end
    
    %% Public methods that take care of calculations that are needed a lot
    methods (Access = public)
        % This function calculates the current volumetric flow rate in m3/s
        % based on the current state of the matter flowing through the
        % flow.
        function fVolumetricFlowRate = calculateVolumetricFlowRate(this, fFlowRate)
            %% calculateVolumetricFlowRate
            % calculates the volumetric flowrate for this flow.
            %
            % Optional Inputs:
            % fFlowRate:    mass flow in kg/s which should be transformed
            %               to a volumetric flow rate using the current
            %               matter properties of this flow If no flowrate
            %               is provided to the function call (the usual use
            %               case) the flowrate of the current flow object
            %               is used to calculate the volumetric flowrate
            %
            % Output:
            % fVolumetricFlowRate:  Volumetric flowrate in m^3/s
            
            if nargin < 2 || isempty(fFlowRate)
                fFlowRate = this.fFlowRate;
            end
            
            if fFlowRate ~= 0
                % Get the current density and then calculate the volumetric
                % flowrate from that value. As it uses the matter table, it
                % is valid in all cases. For gases, if the ideal gas law is
                % used to calculate the density, some discrepancies could
                % occur, but this calculation is more accurate anyway
                fCurrentDensity = this.getDensity();
                fVolumetricFlowRate = fFlowRate / fCurrentDensity;
            else
                % In some cases the pressure/temperature or other values
                % for the flows are not "valid" if the flowrate is zero and
                % therefore the volumetric flowrate is directly set to zero
                % to ensure that a volumetric flowrate of zero is returned
                % (otherwise NaN values are possible, e.g. for a pressure
                % of 0).
                fVolumetricFlowRate = 0;
            end
        end
    end
    

    %% Methods to set matter properties, accessible through handles
    % See above, handles are returned when adding procs or on .seal()
    methods (Access = protected)
        
        function removeIfProc(this)
            %% removeIfProc
            % decouples the flow from the f2f/exme, but only if it is an IF
            if ~this.bInterface
                this.throw('removeProc', 'Can only be done for interface flows.');
            
            elseif isempty(this.oOut)
                this.throw('removeProc', 'Not connected.');
                
            end
            
            this.thRemoveCBs.out();
            
            this.thRemoveCBs.out = [];
            this.oOut = [];
        end
        
    end
        
    methods (Access = {?solver.thermal.base.branch})
        function setTemperature(this, fTemperature)
            %% setTemperature
            % INTERNAL FUNCTION! is called by the thermal solver of the
            % associated thermal branch (which is also asscociated to the
            % matter branch). Only a thermal solver should use this
            % function to set the temperature!
            %
            % Required Inputs:
            % fTemperature:     New Temperature of the flow in K
            this.fTemperature = fTemperature;
            
            % Reset to empty, so if requested again, recalculated!
            if (abs(this.fTemperature - this.tfPropertiesAtLastMassPropertySet.fTemperature) > 0.5)

                this.fDensity          = [];
                this.fDynamicViscosity = [];

                this.tfPropertiesAtLastMassPropertySet.fTemperature = this.fTemperature;
            end
            this.fDensity          = [];
            this.fDynamicViscosity = [];
        end
    end
    methods (Access = {?matter.branch})
        % Only branches are allowed to use the setData function. This is
        % done to prevent data corruption
        function setData(aoFlows, oExme, fFlowRate, afPressures)
            %% setData
            % Sets flow data on an array of flow objects. If flow rate not
            % provided, just molar masses, specific heat capacity,
            % arPartials etc are set. Function handle to this method is
            % provided on seal(), so the branch can access it to set the
            % data for all flows within the branch directly
            %
            % Required Inputs:
            % aoFlows:      Array of the flow objects for which the new
            %               data should be set
            % oExme:        Current in exme of the branch from which the
            %               matter is coming
            % fFlowRate:    new flow rate of the branch and therefore also
            %               the flows
            % afPressures:  the pressure losses (positive values) produced
            %               by the f2fs within the branch. or pressure
            %               rises if the values are negative
            
            % We need the initial pressure and temperature of the inflowing
            % matter, as the values in afPressure / afTemps are relative
            % changes. If e.g. a valve is shut in the branch, this method
            % is however called with the oExme parameter empty, so we need
            % to check that and in that case make no changes to fPressure /
            % fTemperature in the flows. So get pressure/temperature of in
            % exme (if FR provided)
            if nargin >= 3 && ~isempty(oExme)
                fExMePress = oExme.oPhase.fPressure;
            else
                fExMePress = 0;
            end
            
            % Get matter properties of the phase
            if ~isempty(oExme)
                % In some edge cases (the one that triggered the creation
                % of the following code involved manual branches bound to
                % p2p updates) the arPhasePartialMass may be all zeros,
                % even though the phase mass is not zero. In that case,
                % we'll just update the phase.
                if sum(oExme.oPhase.arPartialMass) == 0
                    % Note that registering an actual update here could
                    % lead to a recursive call where a branch while
                    % recalculating itself also sets itself outdated
                   oExme.oPhase.registerMassupdate();
                end
                
                arPhasePartialMass         = oExme.oPhase.arPartialMass;
                fPhaseMolarMass            = oExme.oPhase.fMolarMass;
                fPhaseSpecificHeatCapacity = oExme.oPhase.oCapacity.fSpecificHeatCapacity;
                arFlowCompoundMass         = oExme.oPhase.arCompoundMass;

                % This can occur for example if a flow phase is used, which
                % has an outflow, but not yet an inflow. In that case the
                % partial mass of the phase is zero (as nothing flows in)
                % and the phase is handled like an empty normal phase
                if sum(arPhasePartialMass) == 0
                    fFlowRate = 0;
                end
                
                % If a phase was empty in one of the previous time steps
                % and has had mass added to it, the specific heat capacity
                % may not have yet been calculated, because the phase has
                % not been updated. If the phase does have mass but zero
                % heat capacity, we force an update of this value here. 
                if fPhaseSpecificHeatCapacity == 0 && oExme.oPhase.fMass ~= 0
                    %TODO move the following warning to a lower level debug
                    %output once this is implemented
                    % aoFlows(1).warn('setData', 'Updating specific heat capacity for phase %s %s.', oExme.oPhase.oStore.sName, oExme.oPhase.sName);
                    oExme.oPhase.oCapacity.updateSpecificHeatCapacity();
                    fPhaseSpecificHeatCapacity = oExme.oPhase.oCapacity.fSpecificHeatCapacity;
                end
                
            % If no exme is provided, those values will not be changed (see
            % above, in case of e.g. a closed valve within the branch).
            else
                arPhasePartialMass         = 0;
                fPhaseMolarMass            = 0;
                fPhaseSpecificHeatCapacity = 0;
                afPressures                = zeros(1, length(afPressures));
            end
            
            iL = length(aoFlows);
            
            % If no pressure drops / temperature changes are provided, only
            % set according values in flows if only one flow available,
            % meaning that the branch doesn't contain any f2fs.
            bSkipFRandPT = (nargin < 3) || isempty(fFlowRate);   % skip flow rate, pressure, temp?
            bSkipPT      = (nargin < 4) || (isempty(afPressures) && (iL > 1)); % skip pressure, temp?
            
            if bSkipPT && (iL > 1), aoFlows(1).warn('setData', 'No temperature and/or temperature set for matter.flow(s), but matter.procs.f2f''s exist -> no usable data for those?'); end
            
            % Rounding precision
            iPrec = aoFlows(1).oTimer.iPrecision;
            
            % We need to update the flows in the direction of the flow. In
            % case the flow rate is zero, we'll check the pressures of the
            % connected phases to determine the flow direction. The bNeg
            % boolean variable is set true if the updates have to happen in
            % the negative direction of the branch (i.e. from right to
            % left).
            if fFlowRate == 0
                if strcmp(aoFlows(1).oBranch.coExmes{1}.oPhase.sType, 'gas')
                    fPressureLeft  = aoFlows(1).oBranch.coExmes{1}.oPhase.fMass * aoFlows(1).oBranch.coExmes{1}.oPhase.fMassToPressure;
                    fPressureRight = aoFlows(1).oBranch.coExmes{2}.oPhase.fMass * aoFlows(1).oBranch.coExmes{2}.oPhase.fMassToPressure;
                else
                    fPressureLeft  = aoFlows(1).oBranch.coExmes{1}.oPhase.fPressure;
                    fPressureRight = aoFlows(1).oBranch.coExmes{2}.oPhase.fPressure;
                end
                
                if fPressureLeft > fPressureRight
                    bNeg = false;
                else
                    bNeg = true;
                end
            else
                bNeg = fFlowRate < 0;
            end
       
            if bNeg; aiIndices = iL:-1:1; else; aiIndices = 1:iL; end
            for iI = aiIndices
                oFlow = aoFlows(iI);
                
                % Only set those params if oExme was provided
                if ~isempty(oExme)
                    oFlow.arPartialMass         = arPhasePartialMass;
                    oFlow.fMolarMass            = fPhaseMolarMass;
                    oFlow.arCompoundMass        = arFlowCompoundMass;
                    
                    oFlow.fSpecificHeatCapacity = fPhaseSpecificHeatCapacity;
                end
                
                
                % Skip flowrate, pressure, temperature?
                if bSkipFRandPT, continue; end
                
                oFlow.fFlowRate = fFlowRate;
                
                % If only one flow, no f2f exists --> set pressure, temp
                % according to IN exme
                if iL == 1
                    oFlow.fPressure = fExMePress;
                end
                
                % Skip pressure, temperature?
                if bSkipPT, continue; end
                
                oFlow.fPressure = fExMePress;
                
                if tools.round.prec(fExMePress, iPrec) < 0
                    oFlow.fPressure = 0;
                    
                    % For manual solvers this is not an issue! Check
                    % performed after other checks to save calculation time
                    % in case this is not even an issue at all!
                    if (fExMePress < -10) && ~isa(oFlow.oBranch.oHandler, 'solver.matter.manual.branch')
                        aoFlows(1).warn('setData', 'Setting a negative pressure less than -10 Pa (%f) for the LAST flow in branch "%s"!', fExMePress, aoFlows(1).oBranch.sName);
                    elseif ((~bNeg && iI ~= iL) || (bNeg && iI ~= 1)) && ~isa(oFlow.oBranch.oHandler, 'solver.matter.manual.branch')
                        aoFlows(1).warn('setData', 'Setting a negative pressure, for flow no. %i/%i in branch "%s"!', iI, iL, aoFlows(1).oBranch.sName);
                    end
                elseif tools.round.prec(fExMePress, iPrec) == 0
                    % If the pressure is extremely small, we also set the
                    % flow pressure to zero.
                    oFlow.fPressure = 0;
                end
                
                % Calculates the pressure for the NEXT flow, so make sure
                % this is not the last one!
                % The 'natural' thing to happen (passive components) is a
                % pressure drop, therefore positive values represent
                % pressure drops, negative ones a rise in pressure.
                % I.e. afPressures = afPressureDROPS
                if (bNeg && iI > 1) || (~bNeg && iI < iL)
                    % afPressures contains one element less than the flows
                    % themselves, as afPressure(Drops) is generated by f2fs
                    % which are one less than the flows, e.g.
                    % EXME|FLOW(1)|F2F(1)|FLOW(2)|F2F(2)|FLOW(3)|EXME
                    % Therefore, if we're starting with FLOW(3), we need to
                    % subtract one from the FLOW index to get the last F2F
                    if bNeg
                        iIndex = iI - 1;
                    else
                        iIndex = iI;
                    end
                    fExMePress = fExMePress - afPressures(iIndex);
                end
                
                % Reset to empty, so if requested again, recalculated!
                if (abs(oFlow.fTemperature       - oFlow.tfPropertiesAtLastMassPropertySet.fTemperature) > 0.5) ||...
                    (abs(oFlow.fPressure         - oFlow.tfPropertiesAtLastMassPropertySet.fPressure) > 10) ||...
                    (any(abs(oFlow.arPartialMass - oFlow.tfPropertiesAtLastMassPropertySet.arPartials) > 5e-4))
                
                    oFlow.fDensity          = [];
                    oFlow.fDynamicViscosity = [];
                    
                    oFlow.tfPropertiesAtLastMassPropertySet.fTemperature     = oFlow.fTemperature;
                    oFlow.tfPropertiesAtLastMassPropertySet.fPressure        = oFlow.fPressure;
                    oFlow.tfPropertiesAtLastMassPropertySet.arPartials       = oFlow.arPartialMass;
                end
            end
        end
    end
end
