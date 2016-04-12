classdef flow < base & matlab.mixin.Heterogeneous
    %FLOW 
    
    properties (SetAccess = private, GetAccess = public)
        
        % Electrical current
        % @type float
        fCurrent    = 0;   % [A]
        
        % Voltage
        % @type float
        fVoltage = 0; % [V]
        
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
        
        function this = update(this, fCurrent, fVoltage)
            this.fCurrent = fCurrent;
            this.fVoltage = fVoltage;
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
        
        
    end
    
end

