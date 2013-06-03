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
    %   - see .update() - when to call the update method, provide geometry?
    %   - diameter + fr + pressure etc -> provide dynamic pressure? Also
    %     merge the kinetic energy in exmes?
    %   - some geometry/diamter stuff that allows to define the connection
    %     type for f2f's and prevents connecting incompatible (e.g. diam)?
    
    properties (SetAccess = protected, GetAccess = public)
        
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
        
        % Partial masses in percent (ratio) in indexed vector (use oMT to
        % translate, e.g. this.oMT.tiN2I)
        % Can be empty, won't be accessed if fFlowRate is zero ...?
        % @type array
        arPartialMass;
        
        
        % Reference to the matter table
        % @type object
        oMT;
        
        % Branch the flow belongs to
        oBranch;
        
        % Diameter
        %TODO maybe several phases somehow (linked flows or something?). So
        %     same as in stores: available diameter has to be distributed
        %     throughout the flows (diam - fluid/solid = diam gas)
        % @type float
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
        thFuncs;
    end
    
    %% Public methods
    methods
        function this = flow(oMT, oBranch)
            this.oMT     = oMT;
            
            if nargin >= 2, this.oBranch = oBranch; end;
            
            % Register flow object with the matter table
            this.oMT.addFlow(this);
            
            
            % Preset ...
            this.arPartialMass = zeros(1, this.oMT.iSpecies);
            
            % See thFuncs definition above and addProc below.
            this.thFuncs = struct(...
                ... %TODO check, but FR needs to be set by solver etc, so has public access
                ... 'setFlowRate',    @this.setFlowRate,    ...
                'setPressure',    @this.setPressure,    ...
                'setTemperature', @this.setTemperature, ...
                'setHeatCapacity',@this.setHeatCapacity,...
                'setPartialMass', @this.setPartialMass  ...
            );
        end
        
        
        function this = update(this)
            % At the moment done through the solver specific methods ...
        end
        
        
        function [ setFlowRate hRemoveIfProc ] = seal(this, bIf)
            if this.bSealed
                this.throw('seal', 'Already sealed!');
            end
            
            hRemoveIfProc = [];
            setFlowRate = @this.setFlowRate;
            
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
    
    
    %% Solver Methods - should be in solver.basic.matter.flow?
    %TODO see matter.procs.exme, implement a more general version of these
    %     methods. If a solver needs additional functionality that can't be
    %     implemented by some kind of proxy object that gathers the needed
    %     data from the objects, some way to replace flows/branches/procs
    %     etc with solver-specific derived objects.
    %     Only matter.procs.f2f components have to specificly derive from a
    %     solver class to make sure they implement the according methods.
    methods
        
        function setSolverData(this, oExme, fFlowRate, mfData)
            % Sets the data for a set of flows (can be called on an array
            % of flow objects). 
            %
            % setSolverData parameters:
            %   fFlowRate   - Flow rate to set
            %   oEXME       - depending on flow rate direction, input EXME
            %                 for press/temp init, arPartials from Phase
            %   mfData      - change for press/temp in each proc
            
            
            if nargin >= 4
                [ fPress fTemp ] = oExme.solverExtract();
            else
                fPress = 0;
                fTemp  = 0;
            end
            
            % Also update that stuff - phase was updated, so that might
            % have changed
            if ~isempty(oExme)
                [ arPartialMass, fMolMass, fHeatCapacity ] = oExme.getMatterProperties();
            else
                arPartialMass = 0;
                fMolMass      = 0;
                fHeatCapacity = 0;
            end
            
            iL            = length(this);
            
            for iI = 1:iL
                if ~isempty(oExme)
                    this(iI).arPartialMass = arPartialMass;
                    this(iI).fMolMass      = fMolMass;
                    this(iI).fHeatCapacity = fHeatCapacity;
                end
                
                if nargin < 3, continue; end;
                
                this(iI).fFlowRate = fFlowRate;
                
                if nargin < 4 || isempty(mfData), continue; end;
                
                this(iI).fPressure = fPress;
                this(iI).fTemp     = fTemp;
                
                % The mfData has one row less than we got flows (since last
                % flow connects to EXME, not included in calcDP stuff)
                if iI < iL
                    fPress = fPress - mfData(iI, 1);
                    fTemp  = fTemp  - mfData(iI, 2);
                end
            end
        end
        
        
        
        
        function setSolverInit(this, fFlowRate, oExmeL, oExmeR, bNoPressure)
            % The 'this' variable is in this case (or might be) an array of
            % flows. Order of flows in array is always in flow direction,
            % i.e. if fFlowRate<0, this(1) is the last flow in the branch.
            % 
            % Sets initial values for the flows in the branch, like partial
            % masses (% of flow rate), molecular mass, heat capacity. Pre-
            % sets the temperature with the in temp, distributes the
            % pressure difference between exmes equally.
            %
            %TODO
            %   - Cp can change between flows (temperature)
            %   - 
            
            % Flow from R to L
            if fFlowRate < 0
                oExmeIn      = oExmeR;
                fPressureOut = oExmeL.solverMerge();
            
            % L to R
            else
                oExmeIn      = oExmeL;
                fPressureOut = oExmeR.solverMerge();
            end
            
            % Get pressure, temperature ...
            [ fPressureIn fTemperature ] = oExmeIn.solverExtract();
            
            % Now we know pressure in and out - distribute intermediate
            % pressures in flows equally
            fPressureDiff  = fPressureIn - fPressureOut;
            fPressureDelta = fPressureDiff / (length(this) - 1);
            
            % Get matter properties
            [ arPartialMass, fMolMass, fHeatCapacity ] = oExmeIn.getMatterProperties();
            
            
            for iI = 1:length(this)
                this(iI).fFlowRate     = fFlowRate;
                this(iI).arPartialMass = arPartialMass;
                this(iI).fMolMass      = fMolMass;
                this(iI).fHeatCapacity = fHeatCapacity;
                this(iI).fTemp         = fTemperature;
                
                if nargin >= 5 && bNoPressure, continue; end;
                
                this(iI).fPressure     = fPressureIn - fPressureDelta * (iI - 1);
            end
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
            thFuncs = this.thFuncs;
            
            % Last/first flow in branch, i.e. proc is an exme?
            if isa(oProc, 'matter.procs.exme')
                %TODO bTerminator needed?
                %this.bTerminator = true;
                
            % The proc is f2f - however, f2f's can't set the partial
            % masses, so remove that callback
            else
                thFuncs = rmfield(thFuncs, 'setPartialMass');
            end
        end
        
        % Seems like we need to do that for heterogeneous, if we want to
        % compare the objects in the mixin array with one object ...
        function varargout = eq(varargin)
            varargout{:} = eq@base(varargin{:});
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
        
        
        
        function this = setFlowRate(this, fFlowRate)
            % Set the flow rate for the matter flow in kg/s. Only works if
            % the pressure is >= 0 --> a pressure of -1 means that the flow
            % is "closed".
            
            if this.fPressure > -1
                this.fFlowRate = fFlowRate;
            end
        end
        
        
        function this = setPressure(this, fPressure)
            % Set the pressure in Pa. If the value is Inf, that 
            % means the MF is somehow shut, deactivated or something like 
            % that. In that case, the flow rate is set to zero and the 
            % pressure is set to -1.
            %
            %CHECK doesn't really make sense with fr = 0 here, should or
            %      has to be done/taken into account by the solver anyway.
            
            if isnan(fPressure) || isinf(fPressure)
                this.fPressure = -1;
                
                %TODO if, then should be set for the whole branch!
                this.fFlowRate = 0;
                
            elseif isempty(fPressure) || ~isnumeric(fPressure) || (fPressure < 0)
                this.throw('setPresusre', 'Pressure has to be a non-empty, not negative number ("%s" given)!', num2str(fPressure));
                
            else
                this.fPressure = fPressure;
                
            end
        end
        
        function this = setTemperature(this, fTemperature)
            % Set the temperature in Kelvin!
            
            if isempty(fTemperature) || ~isnumeric(fTemperature) || (fTemperature <= 0)
                this.throw('setTemperature', 'Temperature has to be a non-empty, greater than zero number ("%s" given)!', num2str(fTemperature));
            
            else
                this.fTemp = fTemperature;
            end
        end
        
        function this = setHeatCapacity(this, fHeatCapacity)
            % Set the heat capacity in J/K
            
            if isempty(fHeatCapacity) || ~isnumeric(fHeatCapacity) || (fHeatCapacity <= 0)
                this.throw('setHeatCapacity', 'Heat capcity has to be a non-empty, greater than zero number ("%s" given)!', num2str(fHeatCapacity));
            
            else
                this.fHeatCapacity = fHeatCapacity;
            end
        end
        
        function this = setPartialMass(this, arPartialMass)
            % Set the partial masses (ratios, not absolute values!) for the
            % different species (see matter table)
            
            
            if ~isvector(arPartialMass) || (size(arPartialMass, 1) > 1)
                this.throw('setPartialMass', 'Need a row vector!');
                
            elseif length(arPartialMass) ~= this.oMT.iSpecies
                this.throw('setPartialMass', 'Length %i of provided partial mass vector doesn''t fit the amount of species %i in the matter table!', length(arPartialMass), this.oMT.iSpecies);
                
            else
                this.arPartialMass = arPartialMass;
            end
        end
    end
    
end

