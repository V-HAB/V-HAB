classdef flow < base
    %FLOW A class describing the flow of matter during a discrete timestep
    %   The MatterFlow class is one of the three smalles building blocks in
    %   this simulation. It is used to describe a homogenous flow of matter 
    %   at an interface between two other blocks. 
    %   The flow can only be in one state, so either gaseous,
    %   liquid, solid or plasma. To create a flow with two or more phases,
    %   several MatterFlow objects have to be combined.
    %
    % flow Properties:
    %   oIn     - reference to the 'in' matter.proc
    %
    %TODO
    %   - check if we need a matter.flows.gas, matter.flows.fluid etc ...?
    %       => e.g. fPressure not for solids ...
    %   - see .update() - when to call the update method, provide geometry?
    %   - diameter + fr + pressure etc -> provide dynamic pressure? Also
    %     merge the kinetic energy in exmes?
    %   - some geometry/diamter stuff that allows to define the connection
    %     type for f2f's and prevents connecting incompatible (e.g. diam)?
    %   - Rename to |MassFlow|
    
    properties (SetAccess = private, GetAccess = public)
        
        % Flow rate, pressure and temperature of the matter stream
        fFlowRate    = 0;   % [kg/s]
        
        % Pressure of this flow object
        fPressure    = 0;  % [Pa]
        
        % Temperature of this flow object
        fTemperature = 293;   % [K]
        
        fSpecificHeatCapacity = 0;       % [J/K/kg]
        fMolarMass            = 0;       % [kg/mol]
        
        % Partial masses in percent (ratio) in indexed vector (use oMT to
        % translate, e.g. this.oMT.tiN2I)
        arPartialMass;
        
        
        % Reference to the matter table
        oMT;
        
        % Reference to the timer
        oTimer;
    end
    
    properties (SetAccess = protected, GetAccess = public)
        % Branch the flow belongs to
        oBranch;
        
        % The store the flow belongs to if it is used as the parent class
        % of a p2p processor.
        oStore;
        
        % Diameter
        fDiameter = 0;
    end
    
    properties (SetAccess = private, GetAccess = public)
        % References to the processors connected to the flow (exme || f2f)
        oIn;
        oOut;
        
        % Sealed?
        bSealed = false;
        
        % Interface flow? If yes, can be reconnected even after seal, also
        % the remove callback can be executed for in methods other then
        % delete
        bInterface = false;
        
        % Re-calculated every tick in setData/seal
        afPartialPressure;
        
        % Only recalculated when setData was executed and requested again!
        fDensity;
        fDynamicViscosity;
        
        % Properties to decide when the matter properties have to be
        % recalculated
        fPressureLastMassPropUpdate    = 0;
        fTemperatureLastMassPropUpdate = 0;
        arPartialMassLastMassPropUpdate;

    end
    
    properties (SetAccess = private, GetAccess = private)
        
        thRemoveCBs = struct();
    end
    
    %% Public methods
    methods
        function this = flow(oCreator)
            
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
                this.arPartialMass = zeros(1, this.oMT.iSubstances);
                this.arPartialMassLastMassPropUpdate = this.arPartialMass;
            end
        end
        
        function [ setData, hRemoveIfProc ] = seal(this, bIf, oBranch)
            
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
                    this.arPartialMass = oPhase.arPartialMass;
                    this.fMolarMass    = oPhase.fMolarMass;
                    this.fSpecificHeatCapacity = oPhase.oCapacity.fSpecificHeatCapacity;
                    
                    this.afPartialPressure = this.calculatePartialPressures();
                end

            end
        end
        
        
        function delete(this)
            % Remove references to In/Out proc, also tell that proc about
            % it if it still exists
            
            if ~isempty(this.oIn)  && isvalid(this.oIn),  this.thRemoveCBs.in(); end
            if ~isempty(this.oOut) && isvalid(this.oOut), this.thRemoveCBs.out(); end
            
            this.oIn = [];
            this.oOut = [];
        end
        
        function afPartialPressure = getPartialPressures(this)
            afPartialPressure = [];
            
            this.throw('getPartialPressures', 'Please access afPartialPressure directly!');
        end
        
        
        function fDensity = getDensity(this)
            if isempty(this.fDensity)
                this.fDensity = this.oMT.calculateDensity(this);
            end
            
            
            fDensity = this.fDensity;
        end
        
        
        function fDynamicViscosity = getDynamicViscosity(this)
            if isempty(this.fDynamicViscosity)
                this.fDynamicViscosity = this.oMT.calculateDynamicViscosity(this);
            end
            
            
            fDynamicViscosity = this.fDynamicViscosity;
        end
    end
    
    
    
    
    %% Sealed to ensure flow/f2f proc behaviour
    methods (Sealed = true)
        
        function [ iSign, thFuncs ] = addProc(this, oProc, removeCallBack)
            % Adds the provided processor (has to be or derive from either
            % matter.procs.f2f or matter.procs.exme). If *oIn* is empty,
            % the proc is written on that attribute, and -1 is returned
            % which can be multiplied with fFlowRate to get the correct
            % sign of the flow rate. If oIn is not empty but oOut is, an
            % 1 is returned for iSighn. If none are empty, error thrown.
            
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
            
            % Provide struct with function handles allowing manipulation
            % of matter properties through the protected methods below!
            thFuncs = struct();
        end
    end
    
    %% Public methods that take care of calculations that are needed a lot
    methods (Access = public)
        % This function calculates the current volumetric flow rate in m3/s
        % based on the current state of the matter flowing through the
        % flow.
        function fVolumetricFlowRate = calculateVolumetricFlowRate(this, fFlowRate)
            % If no flowrate is provided to the function call (the usual
            % use case) the flowrate of the current flow object is used to
            % calculate the volumetric flowrate 
            if nargin < 2 || isempty(fFlowRate)
                fFlowRate = this.fFlowRate;
            end
            
            if fFlowRate ~= 0
                % Uses the ideal gas law to calculate the density of the
                % flow and from the density the volumetric flowrate. In non
                % ideal case, or for liquid flows, this calculation is
                % therefore not correct and should not be used! If a
                % non-ideal or liquid case becomes necessary it should be
                % discussed if this calculation can be moved to the matter
                % table and use the calculateDensity function of the matter
                % table.
                fVolumetricFlowRate = fFlowRate / ...
                                    ( this.fPressure * this.fMolarMass / ...
                                    ( this.oMT.Const.fUniversalGas * this.fTemperature  ) );
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

        function setTemperature(this, fTemperature)
            % TO DO: limit acces to respective thermal solver
            this.fTemperature = fTemperature;
        end
    end
    

    %% Methods to set matter properties, accessible through handles
    % See above, handles are returned when adding procs or on .seal()
    methods (Access = protected)
        
        function [ afPartialPressure ] = calculatePartialPressures(this)
            %TODO put in matter.table, see calcHeatCapacity etc (?)
            %     only works for gas -> store phase type in branch? Multi
            %     phase flows through "linked" branches? Or add "parallel"
            %     flows at each point in branch, one for each phase?
            
            % Calculating the number of mols for each species
            afMols = this.arPartialMass ./ this.oMT.afMolarMass;
            % Calculating the total number of mols
            fGasAmount = sum(afMols);
            
            %TODO Do this using matter table!
            %fGasAmount = this.oMT.calculateMols(this);
            
            % Calculating the partial amount of each species by mols
            arFractions = afMols ./ fGasAmount;
            % Calculating the partial pressures by multiplying with the
            % total pressure in the phase
            afPartialPressure = arFractions .* this.fPressure;
        end
        
        function removeIfProc(this)
            % Decouple from processor - only possible if interface flow!
            if ~this.bInterface
                this.throw('removeProc', 'Can only be done for interface flows.');
            
            elseif isempty(this.oOut)
                this.throw('removeProc', 'Not connected.');
                
            end
            
            
            this.thRemoveCBs.out();
            
            this.thRemoveCBs.out = [];
            this.oOut = [];
        end
        
        
        function setMatterProperties(this, fFlowRate, arPartialMass, fTemperature, fPressure)
            % For derived classes of flow, can set the matter properties 
            % through this method manually. In contrast to setData, this 
            % method does not get information automatically from the 
            % inflowing exme but just uses the provided values. This allows
            % derived, but still generic classes (namely matter.p2ps.flow 
            % and matter.p2ps.stationary) to ensure control over the actual
            % processor implementatins when they set the flow properties.
            
            this.fFlowRate     = fFlowRate;
            this.arPartialMass = arPartialMass;
            this.fTemperature  = fTemperature;
            this.fPressure     = fPressure;
            
            if this.fFlowRate >= 0
                oPhase = this.oIn.oPhase;
            else
                oPhase = this.oOut.oPhase;
            end
            
            this.fSpecificHeatCapacity = oPhase.oCapacity.fSpecificHeatCapacity;
            this.fMolarMass            = oPhase.fMolarMass;
        end
        
        
        
        function setData(aoFlows, oExme, fFlowRate, afPressures)
            % Sets flow data on an array of flow objects. If flow rate not
            % provided, just molar masses, cp, arPartials etc are set.
            % Function handle to this method is provided on seal(), so the
            %
            %TODO
            % - This method does not need to be part of the flow class. It
            %   is called only by the matter.branch class and it does not
            %   use any private or protected properties and methods of the
            %   flow object it is being called on. Therfore it could be
            %   moved to the matter.branch class. 
            % - right now, solver provide flow rate and pressure drops in
            %   'sync', i.e. if flow rate is negative, pressure drops will
            %   be negative values. Should all that be handled here?
            
            % We need the initial pressure and temperature of the inflowing
            % matter, as the values in afPressure / afTemps are relative
            % changes. If e.g. a valve is shut in the branch, this method
            % is however called with the oExme parameter empty, so we need
            % to check that and in that case make no changes to fPressure /
            % fTemperature in the flows. So get pressure/temperature of in
            % exme (if FR provided)
            if nargin >= 3 && ~isempty(oExme)
                %TODO get exme from this.oBranch, depending on fFlowRate?
                [ fPortPress, ~ ] = oExme.getPortProperties();
            else
                fPortPress = 0;
            end
            
            % Get matter properties of the phase
            if ~isempty(oExme)
                [ arPhasePartialMass, fPhaseMolarMass, fPhaseSpecificHeatCapacity ] = oExme.getMatterProperties();
                
                % In some edge cases (the one that triggered the creation
                % of the following code involved manual branches bound to
                % p2p updates) the arPhasePartialMass may be all zeros,
                % even though the phase mass is not zero. In that case,
                % we'll just update the phase.
                if oExme.oPhase.bFlow
                    if sum(arPhasePartialMass) == 0 && oExme.oPhase.fCurrentTotalMassInOut ~= 0
                        oExme.oPhase.registerUpdate();
                        [ arPhasePartialMass, fPhaseMolarMass, fPhaseSpecificHeatCapacity ] = oExme.getMatterProperties();
                    end
                else
                    if sum(arPhasePartialMass) == 0 && oExme.oPhase.fMass ~= 0
                        oExme.oPhase.registerUpdate();
                        [ arPhasePartialMass, fPhaseMolarMass, fPhaseSpecificHeatCapacity ] = oExme.getMatterProperties();
                    end
                end
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
            %TODO check - do we need the isempty check at all? Just throw
            %     out? Check for isnan() or something?
            bSkipFRandPT = (nargin < 3) || isempty(fFlowRate);   % skip flow rate, pressure, temp?
            bSkipPT      = (nargin < 4) || (isempty(afPressures) && (iL > 1)); % skip pressure, temp?
            %bSkipT       = (nargin < 5) || (isempty(afTemps) && (iL > 1));     % skip temp?
            
            %TODO find out correct behaviour here ... don't set pressures
            %     or temps (from solver init?) if those params are empty or
            %     not provided --> but they're also empty if no f2fs exist
            %     in this branch!!
            %     then however length(this) == 1 -> use that?
            %     or just ALWAYS set the flow params for those flows
            %     directly connected to the EXMEs?
            %     ALSO: if no afPress/afTemps, just distribute equally!?
            %if bSkipT || bSkipPT, this.warn('setData', 'setData on flows w/o press/temp (or just empty) --> difference: no delta temp/press (cause no f2f) or really don''t set??'); end;
            %if (bSkipT || bSkipPT) && (iL > 1), this.warn('setData', 'No temperature and/or temperature set for matter.flow(s), but matter.procs.f2f''s exist -> no usable data for those?'); end;
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
                oThis = aoFlows(iI);
                
                % Only set those params if oExme was provided
                if ~isempty(oExme)
                    oThis.arPartialMass         = arPhasePartialMass;
                    oThis.fMolarMass            = fPhaseMolarMass;
                    
                    oThis.fSpecificHeatCapacity = fPhaseSpecificHeatCapacity;
                end
                
                
                % Skip flowrate, pressure, temperature?
                if bSkipFRandPT, continue; end
                
                oThis.fFlowRate = fFlowRate;
                
                % If only one flow, no f2f exists --> set pressure, temp
                % according to IN exme
                if iL == 1
                    oThis.fPressure    = fPortPress;
                end
                
                
                
                
                % Skip pressure, temperature?
                if bSkipPT, continue; end
                
                oThis.fPressure = fPortPress;
                
                if tools.round.prec(fPortPress, iPrec) < 0
                    oThis.fPressure = 0;
                    
                    % FOr manual solvers this is not an issue!
                    if ~isa(oThis.oBranch.oHandler, 'solver.matter.manual.branch')
                        if fPortPress < -10
                            aoFlows(1).warn('setData', 'Setting a negative pressure less than -10 Pa (%f) for the LAST flow in branch "%s"!', fPortPress, aoFlows(1).oBranch.sName);
                        elseif (~bNeg && iI ~= iL) || (bNeg && iI ~= 1)
                            aoFlows(1).warn('setData', 'Setting a negative pressure, for flow no. %i/%i in branch "%s"!', iI, iL, aoFlows(1).oBranch.sName);
                        end
                    end
                elseif tools.round.prec(fPortPress, iPrec) == 0
                    % If the pressure is extremely small, we also set the
                    % flow pressure to zero.
                    oThis.fPressure = 0;
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
                    fPortPress = fPortPress - afPressures(iIndex);
                end
                
                % Re-calculate partial pressures
                oThis.afPartialPressure = oThis.calculatePartialPressures();
                
                % Reset to empty, so if requested again, recalculated!
                oThis.fDensity          = [];
                oThis.fDynamicViscosity = [];
            end
        end
    end
end
