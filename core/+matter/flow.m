classdef flow < base & matlab.mixin.Heterogeneous
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
    
    properties (SetAccess = private, GetAccess = public)
        
        % Flow rate, pressure and temperature of the matter stream
        % Initialize NOT with empty but some number ...?
        % @type float
        fFlowRate    = 0;   % [kg/s]
        
        % @type float
        fPressure    = 0;  % [Pa]
        
        % @type float
        fTemp        = 0;   % [K]
        
        
        
        %TODO implement .update, get heat capacity depending on
        %     arPartialMass and Temperature
        fHeatCapacity = 0;      % [J/K/kg]
        fMolMass      = 0;      % [g/mol] NOT KG!
        fMolarMass    = 0;      % [kg/mol]
        
        % Partial masses in percent (ratio) in indexed vector (use oMT to
        % translate, e.g. this.oMT.tiN2I)
        % Can be empty, won't be accessed if fFlowRate is zero ...?
        % @type array
        % @types float
        arPartialMass;
        
        
        % Reference to the matter table
        % @type object
        oMT;
    end
    
    properties (SetAccess = protected, GetAccess = public)
        % Branch the flow belongs to
        oBranch;
        
        % Diameter
        %TODO maybe several phases somehow (linked flows or something?). So
        %     same as in stores: available diameter has to be distributed
        %     throughout the flows (diam - fluid/solid = diam gas)
        % @type float
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
    end
    
    properties (SetAccess = private, GetAccess = private)
        
        thRemoveCBs = struct();
    end
    
    %TODO check if private is ok - done to ensure that flow always handles
    %     the matter stuff the same way (according methods are sealed)
    properties (SetAccess = private, GetAccess = private)
        % Struct with function handles to the methods to set matter
        % properties. Can be extended by derived classes if required.
        % Is returned to the f2f/exme procs whose base classes ensure that
        % they can only be called if the matter flow is actually flowing
        % from the processor into the flow!
        % NOW inactive.
        %thFuncs;
    end
    
    %% Public methods
    methods
        function this = flow(oMT, oBranch)
            this.oMT     = oMT;
            
            if nargin >= 2, this.oBranch = oBranch; end;
            
            % Register flow object with the matter table
            this.oMT.addFlow(this);
            
            
            % Preset ...
            this.arPartialMass = zeros(1, this.oMT.iSubstances);
            
            % See thFuncs definition above and addProc below.
%             this.thFuncs = struct(...
%                 ... %TODO check, but FR needs to be set by solver etc, so has public access
%                 ... 'setFlowRate',    @this.setFlowRate,    ...
%                 'setPressure',    @this.setPressure,    ...
%                 'setTemperature', @this.setTemperature, ...
%                 'setHeatCapacity',@this.setHeatCapacity,...
%                 'setPartialMass', @this.setPartialMass  ...
%             );
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
        end
        
        
        function delete(this)
            % Remove references to In/Out proc, also tell that proc about
            % it if it still exists
            
            if ~isempty(this.oIn)  && isvalid(this.oIn),  this.thRemoveCBs.in(); end;
            if ~isempty(this.oOut) && isvalid(this.oOut), this.thRemoveCBs.out(); end;
            
            this.oIn = [];
            this.oOut = [];
        end
        
        function [ afPartialPressures ] = getPartialPressures(this)
            %TODO put in matter.table, see calcHeatCapacity etc (?)
            %     only works for gas -> store phase type in branch? Multi
            %     phase flows through "linked" branches? Or add "parallel"
            %     flows at each point in branch, one for each phase?
            
            % Calculating the number of mols for each species
            afMols = this.arPartialMass ./ this.oMT.afMolMass;
            % Calculating the total number of mols
            fGasAmount = sum(afMols);
            
            %TODO Do this using matter table!
            %fGasAmount = this.oMT.calculateMols(this);
            
            % Calculating the partial amount of each species by mols
            arFractions = afMols ./ fGasAmount;
            % Calculating the partial pressures by multiplying with the
            % total pressure in the phase
            afPartialPressures = arFractions .* this.fPressure;
        end
    end
    
    
    
    
    %% Sealed to ensure flow/f2f proc behaviour
    methods (Sealed = true)
        
        function [ iSign thFuncs ] = addProc(this, oProc, removeCallBack)
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
            if ~isa(oProc, 'matter.procs.f2f') && ~isa(oProc, 'matter.procs.exme')
                this.throw('addProc', 'Provided proc is not a or derives from either matter.procs.f2f or matter.procs.exme!');
                
            % Ensures that flow can only be added through proc addFlow
            % methods, since aoFlows attribute has SetAccess private!
            elseif ~any(oProc.aoFlows == this) %oProc.aoFlows(iIdxThisFlow) ~= this
                this.throw('addProc', 'Object on proc aoFlows not the same as this one - use proc addFlow method!');
            
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
            %thFuncs = this.thFuncs;
            
            % Last/first flow in branch, i.e. proc is an exme?
            if isa(oProc, 'matter.procs.exme')
                %TODO bTerminator needed?
                %this.bTerminator = true;
                
            % The proc is f2f - however, f2f's can't set the partial
            % masses, so remove that callback
            else
                %thFuncs = rmfield(thFuncs, 'setPartialMass');
            end
            
            thFuncs = struct();
        end
        
        % Seems like we need to do that for heterogeneous, if we want to
        % compare the objects in the mixin array with one object ...
        function varargout = eq(varargin)
            varargout{:} = eq@base(varargin{:});
        end
    end
    
    
    
    
    %% Solver Methods - should be in solver.basic.matter.flow?
    %TODO see matter.procs.exme, implement a more general version of these
    %     methods. If a solver needs additional functionality that can't be
    %     implemented by some kind of proxy object that gathers the needed
    %     data from the objects, some way to replace flows/branches/procs
    %     etc with solver-specific derived objects.
    %     Only matter.procs.f2f components have to specificly derive from a
    %     solver class to make sure they implement the according methods.
    methods
        % SEE BELOW
    end
    
    %% Public methods that take care of calculations that are needed a lot
    methods (Access = public)
        % This function calculates the current volumetric flow rate based
        % on the current state of the matter flowing through the flow.
        function fVolumetricFlowRate = calculateVolumetricFlowRate(this)
            if this.fFlowRate
                fVolumetricFlowRate = this.fFlowRate / ...
                                    ( this.fPressure * this.fMolMass / ...
                                    ( this.oMT.Const.fUniversalGas * this.fTemp  ) );
            else
                fVolumetricFlowRate = 0;
            end
        end
    end
    

    %% Methods to set matter properties, accessible through handles
    % See above, handles are returned when adding procs or on .seal()
    methods (Access = protected)
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
        
        
        
        
        function setMatterProperties(this, fFlowRate, arPartialMass, fTemp, fPressure)%, fHeatCapacity, fMolMass)
            % For derived classes of flow, can set the matter properties 
            % through this method manually. Other than setData, this method
            % does not get information automatically from the inflowing
            % exme but just uses the provided values.
            % This allows derived, but still generic classes (namely 
            % matter.p2ps.flow and matter.p2ps.stationary) to ensure
            % control over the actual processor implementatins when they
            % set the flow properties.
            %
            % Is only called by p2p (?), only ONE flow
            
            this.fFlowRate     = fFlowRate;
            this.arPartialMass = arPartialMass;
            this.fTemp         = fTemp;
            this.fPressure     = fPressure;
            
            % Calculate molecular mass. Normally, the phase uses this 
            % method and provides a vector of absolute masses. Here, the
            % partial mass is used, which should make no difference.
            this.fMolMass = this.oMT.calculateMolecularMass(this.arPartialMass);
            
            % Heat capacity. The oBranch references back to the p2p itself
            % which provides the getInEXME method (p2p is always directly
            % connected to EXMEs).
            this.fHeatCapacity = this.oMT.calculateHeatCapacity(this);
        end
        
        
        
        function setData(this, oExme, fFlowRate, afPressures)
            % Sets flow data on an array of flow objects. If flow rate not
            % provided, just mol masses, cp, arPartials etc are set.
            % Function handle to this method is provided on seal(), so the
            % branch can set stuff.
            %
            % Is only called by branch (?), for all flows in branch
            %
            %
            %TODO
            % - right now, solver provide flow rate and pressure drops in
            %   'sync', i.e. if flow rate is negative, pressure drops will
            %   be negative values. Should all that be handled here?
            
            % We need the initial pressure and temperature of the inflowing
            % matter, as the values in afPressure / afTemps are relative
            % changes.
            % If e.g. a valve is shut in the branch, this method is however
            % called without those params, so we need to check that and in
            % that case make no changes to fPressure / fTemp in the flows.
            % So get pressure/temperature of in exme (if FR provided)
            if nargin >= 3
                %TODO get exme from this.oBranch, depending on fFlowRate?
                [ fPortPress, fCurrTemp ] = oExme.getPortProperties();
            else
                fPortPress = 0;
                fCurrTemp  = 0;
            end
            
            % Get matter properties of the phase
            if ~isempty(oExme)
                [ arPhasePartialMass, fPhaseMolMass, fPhaseHeatCapacity ] = oExme.getMatterProperties();
            
            % If no exme is provided, those values will not be changed (see
            % above, in case of e.g. a closed valve within the branch).
            else
                arPhasePartialMass = 0;
                fPhaseMolMass      = 0;
                fPhaseHeatCapacity = 0;
            end
            
            iL = length(this);
            
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
            if bSkipPT && (iL > 1), this.warn('setData', 'No temperature and/or temperature set for matter.flow(s), but matter.procs.f2f''s exist -> no usable data for those?'); end;
            
            % Rounding precision
            iPrec = this(1).oBranch.oContainer.oTimer.iPrecision;
            
            % Negative flow rate? Need to do everything in reverse
            bNeg = fFlowRate < 0;
            
            for iI = sif(bNeg, iL:-1:1, 1:iL)
                % Only set those params if oExme was provided
                if ~isempty(oExme)
                    this(iI).arPartialMass = arPhasePartialMass;
                    this(iI).fMolMass      = fPhaseMolMass;
                    this(iI).fHeatCapacity = fPhaseHeatCapacity;
                end
                
                
                % Skip flowrate, pressure, temperature?
                if bSkipFRandPT, continue; end;
                
                this(iI).fFlowRate = fFlowRate;
                
                % If only one flow, no f2f exists --> set pressure, temp
                % according to IN exme
                if iL == 1
                    this.fPressure = fPortPress;
                    this.fTemp     = fPortTemp;
                end
                
                
                % Set temperature based on fHeatFlow in f2fs
                % First and last Flows directly use the EXMEs value, so
                % no f2f in between - just set port temperatures directly
                %TODO if flow rate is zero, what to do? Something HAS to
                %     heat up ... heating up in the branch should basically
                %     lead to a flow rate, right?
                if fFlowRate > 0
                    if ~bNeg && (iI > 1)
                        fHeatFlow = this(iI).oIn.fHeatFlow;

                        %NOTE at the moment, one heat capacity throughout all
                        %     flows in the branch. However, at some point, 
                        %     might be replaced with e.g. pressure dep. value?
                        fOtherCp  = this(iI - 1).fHeatCapacity;

                    elseif bNeg && (iL < iI)
                        fHeatFlow = this(iI).oOut.fHeatFlow;
                        fOtherCp  = this(iI + 1).fHeatCapacity;

                    else
                        fHeatFlow = 0;
                        fOtherCp  = this(iI).fHeatCapacity;
                    end

                    % So following this equation:
                    % Q' = m' * c_p * deltaT
                    fCurrTemp = fCurrTemp + fHeatFlow / fFlowRate / ((this(iI).fHeatCapacity + fOtherCp) / 2);
                end
                
                this(iI).fTemp = fCurrTemp;
                
                
                
                
                % Skip pressure, temperature?
                if bSkipPT, continue; end;
                
                this(iI).fPressure = fPortPress;
                
                if tools.round.prec(fPortPress, iPrec) < 0
                    this(iI).fPressure = 0;
                    
                    % Only warn for > 1Pa ... because ...
                    if fPortPress < -10
                        this(1).warn('setData', 'Setting a negative pressure lt -1Pa (%f) for the LAST flow in branch "%s"!', fPortPress, this(1).oBranch.sName);
                    elseif (~bNeg && iI ~= iL) || (bNeg && iI ~= 1)
                        this(1).warn('setData', 'Setting a negative pressure, for flow no. %i/%i in branch "%s"!', iI, iL, this(1).oBranch.sName);
                    end
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
                
                
                % Skip temperature?
%                 if bSkipT, continue; end;
%                 
%                 this(iI).fTemp = fCurrTemp;
%                 
%                 % Due to friction etc, the 'natural' thing is that the
%                 % temperature increases, therefore: positive values
%                 % represent a temperature INCREASE.
%                 %TODO right now afTemps represents temperature DROPS,
%                 %     change that?
%                 if iI < iL, fCurrTemp = fCurrTemp - afTemps(iI); end;
            end
            

%             disp('---');
%             disp([ this.fFlowRate ]);
%             disp([ this.fPressure ]);
%             disp([ this.fTemp ]);
        end
    end
    
end

