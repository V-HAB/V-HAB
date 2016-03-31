classdef flow < base & matlab.mixin.Heterogeneous
    %FLOW 
    
    properties (SetAccess = private, GetAccess = public)
        
        % Electrical current
        % @type float
        fCurrent    = 0;   % [A]
        
        % Reference to the timer
        % @type object
        oTimer;
    end
    
    properties (SetAccess = protected, GetAccess = public)
        % Branch the flow belongs to
        oBranch;
    end
    
    properties (SetAccess = private, GetAccess = public)
        % References to the objects connected to the flow (terminal || component)
        oIn;
        oOut;
        
        thRemoveCBs = struct();
        
        % Sealed?
        bSealed = false;
        
        % Interface flow? If yes, can be reconnected even after seal, also
        % the remove callback can be executed for in methods other then
        % delete
        bInterface = false;
    end
    
    
    
    
    %% Public methods
    methods
        function this = flow(oBranch)
            
            this.oTimer = oBranch.oTimer;
            
            this.oBranch = oBranch;
            
            
        end
        
        
        function this = update(this)
            disp('flow update')
            % At the moment done through the solver specific methods ...
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

                
                
                

            end % if not an interface flow
        end
        
        
        function delete(this)
            % Remove references to In/Out proc, also tell that proc about
            % it if it still exists
            
            if ~isempty(this.oIn)  && isvalid(this.oIn),  this.thRemoveCBs.in(); end;
            if ~isempty(this.oOut) && isvalid(this.oOut), this.thRemoveCBs.out(); end;
            
            this.oIn = [];
            this.oOut = [];
        end
    end
    
    
    
    
    %% Sealed to ensure flow/f2f proc behaviour
    methods (Sealed = true)
        
        function addComponent(this, oComponent, removeCallBack)
            % Adds the provided processor (has to be or derive from either
            % matter.procs.f2f or matter.procs.exme). If *oIn* is empty,
            % the proc is written on that attribute, and -1 is returned
            % which can be multiplied with fFlowRate to get the correct
            % sign of the flow rate. If oIn is not empty but oOut is, an
            % 1 is returned for iSighn. If none are empty, error thrown.
            %
            %TODO 
            %   - also store the port for the oProc?
            %   - call a method on oProc and provide a function handle
            %     which allows manipulation of the stuff here?
            
            % Proc of right type?
            if ~isa(oComponent, 'electrical.component')
                this.throw('addComponent', 'Provided component is not a or does not derive from electrical.component!');
                
            % Ensures that flow can only be added through proc addFlow
            % methods, since aoFlows attribute has SetAccess private!
            if ~any(oComponent.aoFlows == this)
                this.throw('addComponent', 'Object component aoFlows property is not the same as this one - use component''s addFlow method!');
            end
            
            % If sealed, can only do if also an interface. Additional check
            % for oIn just to make sure only oOut can be reconnected.
            elseif this.bSealed && (~this.bInterface || isempty(this.oIn))
                this.throw('addComponent', 'Can''t create branches any more, sealed.');
            
            end
            
           
            
            if isempty(this.oIn)
                this.oIn = oComponent;
                
                
                this.thRemoveCBs.in = removeCallBack;
                
            elseif isempty(this.oOut)
                this.oOut = oComponent;
                
                
                this.thRemoveCBs.out = removeCallBack;
                
            else
                this.throw('addComponent', 'Both oIn and oOut are already set');
            end
            
        end
        
        % Seems like we need to do that for heterogeneous, if we want to
        % compare the objects in the mixin array with one object ...
        function varargout = eq(varargin)
            varargout{:} = eq@base(varargin{:});
        end
    end
    
    
    
    
    
    
    %% Methods to set properties, accessible through handles
    % See above, handles are returned when adding procs or on .seal()
    methods (Access = protected)
        
        function removeInterfaceComponent(this)
            % Decouple from processor - only possible if interface flow!
            if ~this.bInterface
                this.throw('removeInterfaceComponent', 'Can only be done for interface flows.');
            
            elseif isempty(this.oOut)
                this.throw('removeInterfaceComponent', 'Not connected.');
                
            end
            
            
            this.thRemoveCBs.out();
            
            this.thRemoveCBs.out = [];
            this.oOut = [];
        end
        
        function setData(aoFlows, oExme, fFlowRate, afPressures)
            % Sets flow data on an array of flow objects. If flow rate not
            % provided, just molar masses, cp, arPartials etc are set.
            % Function handle to this method is provided on seal(), so the
            % branch can set stuff.
            %
            % Is only called by branch (?), for all flows in branch
            %
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
                [ fPortPress, fCurrentTemperature ] = oExme.getPortProperties();
            else
                fPortPress = 0;
                fCurrentTemperature  = 0;
            end
            
            % Get matter properties of the phase
            if ~isempty(oExme)
                [ arPhasePartialMass, fPhaseMolarMass, fPhaseSpecificHeatCapacity ] = oExme.getMatterProperties();
                
                % If a phase was empty in one of the previous time steps
                % and has had mass added to it, the specific heat capacity
                % may not have yet been calculated, because the phase has
                % not been updated. If the phase does have mass but zero
                % heat capacity, we force an update of this value here. 
                if fPhaseSpecificHeatCapacity == 0 && oExme.oPhase.fMass ~= 0
                    %TODO move the following warning to a lower level debug
                    %output once this is implemented
                    aoFlows(1).warn('setData', 'Updating specific heat capacity for phase %s %s.', oExme.oPhase.oStore.sName, oExme.oPhase.sName);
                    oExme.oPhase.updateSpecificHeatCapacity();
                    fPhaseSpecificHeatCapacity = oExme.oPhase.fSpecificHeatCapacity;
                end

            
            % If no exme is provided, those values will not be changed (see
            % above, in case of e.g. a closed valve within the branch).
            else
                arPhasePartialMass         = 0;
                fPhaseMolarMass            = 0;
                fPhaseSpecificHeatCapacity = 0;
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
            if bSkipPT && (iL > 1), aoFlows(1).warn('setData', 'No temperature and/or temperature set for matter.flow(s), but matter.procs.f2f''s exist -> no usable data for those?'); end;
            
            % Rounding precision
            iPrec = aoFlows(1).oBranch.oContainer.oTimer.iPrecision;
            
            % Negative flow rate? Need to do everything in reverse
            bNeg = fFlowRate < 0;
            
            for iI = sif(bNeg, iL:-1:1, 1:iL)
                oThis = aoFlows(iI);
                
                % Only set those params if oExme was provided
                if ~isempty(oExme)
                    oThis.arPartialMass         = arPhasePartialMass;
                    oThis.fMolarMass            = fPhaseMolarMass;
                    
                    oThis.fSpecificHeatCapacity = fPhaseSpecificHeatCapacity;
                end
                
                % Skip flowrate, pressure, temperature?
                if bSkipFRandPT, continue; end;
                
                oThis.fFlowRate = fFlowRate;
                
                % If only one flow, no f2f exists --> set pressure, temp
                % according to IN exme
                if iL == 1
                    oThis.fPressure    = fPortPress;
                    oThis.fTemperature = fCurrentTemperature;
                end
                
                
                % Set temperature based on fHeatFlow in f2fs
                % First and last Flows directly use the EXMEs value, so
                % no f2f in between - just set port temperatures directly
                %TODO if flow rate is zero, what to do? Something HAS to
                %     heat up ... heating up in the branch should basically
                %     lead to a flow rate, right?
                if abs(fFlowRate) > 0
                    if ~bNeg && (iI > 1)
                        fHeatFlow = oThis.oIn.fHeatFlow;

                        %NOTE at the moment, one heat capacity throughout all
                        %     flows in the branch. However, at some point, 
                        %     might be replaced with e.g. pressure dep. value?
                        fOtherCp  = aoFlows(iI - 1).fSpecificHeatCapacity;

                    elseif bNeg && (iI < iL)
                        fHeatFlow = oThis.oOut.fHeatFlow;
                        fOtherCp  = aoFlows(iI + 1).fSpecificHeatCapacity;

                    else
                        fHeatFlow = 0;
                        fOtherCp  = oThis.fSpecificHeatCapacity;
                    end

                    % So following this equation:
                    % Q' = m' * c_p * deltaT
                    %fCurrentTemperature = fCurrentTemperature + fHeatFlow / abs(fFlowRate) / ((oThis.fSpecificHeatCapacity + fOtherCp) / 2);
                    fCurrentTemperature = fCurrentTemperature + fHeatFlow / abs(fFlowRate) / fOtherCp;
                end
                
                if isnan(fCurrentTemperature)
                    warning(['On branch: %s\n',...
                             '         Temperature of connected phase (%s_%s) is NaN.\n',...
                             '         Using standard temperature instead.\n',...
                             '         Reason could be empty phase.'],...
                             oThis.oBranch.sName, oExme.oPhase.oStore.sName, oExme.oPhase.sName);
                    fCurrentTemperature = oThis.oMT.Standard.Temperature;
                end
                
                oThis.fTemperature = fCurrentTemperature;
                
                % Skip pressure, temperature?
                if bSkipPT, continue; end;
                
                oThis.fPressure = fPortPress;
                
                if tools.round.prec(fPortPress, iPrec) < 0
                    oThis.fPressure = 0;
                    
                    % Only warn for > 1Pa ... because ...
                    if fPortPress < -10
                        aoFlows(1).warn('setData', 'Setting a negative pressure less than -10 Pa (%f) for the LAST flow in branch "%s"!', fPortPress, aoFlows(1).oBranch.sName);
                    elseif (~bNeg && iI ~= iL) || (bNeg && iI ~= 1)
                        aoFlows(1).warn('setData', 'Setting a negative pressure, for flow no. %i/%i in branch "%s"!', iI, iL, aoFlows(1).oBranch.sName);
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
                    fPortPress = fPortPress - afPressures(iI - sif(bNeg, 1, 0));
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

