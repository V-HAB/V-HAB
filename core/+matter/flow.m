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
        fFlowRate    = 0;   % [kg/s]
        fPressure    = 0;  % [Pa]
        fTemp        = 0;   % [K]
        
        %TODO implement .update, get heat capacity depending on
        %     arPartialMass and Temperature
        fHeatCapacity = 0;      % [J/K/kg]
        fMolMass      = 0;      % [g/mol] NOT KG!
        
        % Partial masses in percent (ratio) in indexed vector (use oMT to
        % translate, e.g. this.oMT.tiN2I)
        % Can be empty, won't be accessed if fFlowRate is zero ...?
        arPartialMass;
        
        
        % Matter table
        oMT;
    end
    
    properties (SetAccess = protected, GetAccess = public)
        % Branch the flow belongs to
        oBranch;
        
        % Diameter
        %TODO maybe several phases somehow (linked flows or something?). So
        %     same as in stores: available diameter has to be distributed
        %     throughout the flows (diam - fluid/solid = diam gas)
        %     MOVE to protected SetAccess
        fDiameter;
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
            % At the moment done through the solver specific methods ...
        end
        
        
        function [ setData, hRemoveIfProc ] = seal(this, bIf)
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
            
            % Heat capacity. Normally, the phase passes an object of its
            % own, which allows the matter table to e.g. find out the phase
            % type (gas, liquid etc).
            % Here we pass that information directly, calcHeatCap checks
            % for that case. The oBranch references back to the p2p itself
            % which provides the getInEXME method (p2p is always directly
            % connected to EXMEs).
            sPhaseType = this.oBranch.getInEXME().oPhase.sType;
            
            %CHECK: This might also be done by just passing the phase object to
            % the matter table directly... I don't know why this is done
            % like this. It could save an if condition in table.m
            this.fHeatCapacity = this.oMT.calculateHeatCapacity(sPhaseType, this.arPartialMass, this.fTemp, this.fPressure);
        end
        
        
        
        function setData(this, oExme, fFlowRate, afPressures, afTemps)
            % Sets flow data on an array of flow objects. If flow rate not
            % provided, just mol masses, cp, arPartials etc are set.
            % Function handle to this method is provided on seal(), so the
            % branch can set stuff.
            %
            % Is only called by branch (?), for all flows in branch
            
            % We need the initial pressure and temperature of the inflowing
            % matter, as the values in afPressure / afTemps are relative
            % changes.
            % If e.g. a valve is shut in the branch, this method is however
            % called without those params, so we need to check that and in
            % that case make no changes to fPressure / fTemp in the flows.
            if nargin >= 4
                [ fPortPress, fPortTemp ] = oExme.getPortProperties();
            else
                fPortPress = 0;
                fPortTemp  = 0;
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
            bSkipFRandPT = (nargin < 3) || isempty(fFlowRate);   % skip flow rate, pressure, temp?
            bSkipPT      = (nargin < 4) || isempty(afPressures); % skip pressure, temp?
            bSkipT       = (nargin < 5) || isempty(afTemps);     % skip temp?
            
            for iI = 1:iL
                % Only set those params if oExme was provided
                if ~isempty(oExme)
                    this(iI).arPartialMass = arPhasePartialMass;
                    this(iI).fMolMass      = fPhaseMolMass;
                    this(iI).fHeatCapacity = fPhaseHeatCapacity;
                end
                
                
                % Skip flowrate, pressure, temperature?
                if bSkipFRandPT, continue; end;
                
                this(iI).fFlowRate = fFlowRate;
                
                
                % Skip pressure, temperature?
                if bSkipPT, continue; end;
                
                this(iI).fPressure = fPortPress;
                
                % Calculates the pressure for the NEXT flow, so make sure
                % this is not the last one!
                if iI < iL, fPortPress = fPortPress - afPressures(iI); end;
                
                
                % Skip temperature?
                if bSkipT, continue; end;
                
                this(iI).fTemp = fPortTemp;
                
                if iI < iL, fPortTemp = fPortTemp - afTemps(iI); end;
            end
        end
    end
    
end

