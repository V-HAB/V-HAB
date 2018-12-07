classdef flow < base
    %FLOW A class defining an electrical flow
    %   An electrical flow is characterized by its voltage and current,
    %   therfore these are the main properties of this class. 
    
    properties (SetAccess = private, GetAccess = public)
        % These properties are private to ensure only the flows themselves
        % can change them. 
        
        % Electrical current in [A]
        fCurrent = 0;
        
        % Voltage in [V]
        fVoltage = 0;
        
        % Reference to the timer
        oTimer;
        
        % Reference to the branch the flow belongs to
        oBranch;
        
        % Reference to the object connected to the flow on the 'right'.
        % Can be terminal or component.
        oIn;
        
        % Reference to the object connected to the flow on the 'left'.
        % Can be terminal or component.
        oOut;
        
        % A struct containing function handles to remove the flow from its
        % connected components
        thRemoveCBs = struct();
        
        % A boolean describing the state of this flow. If it is sealed,
        % nothing about its configuration can be changed. 
        bSealed = false;
        
        % Interface flow? If yes, can be reconnected even after seal, also
        % the remove callback can be executed for in methods other than
        % delete
        bInterface = false;
    end
    
    %% Public methods
    methods
        function this = flow(oBranch)
            % Setting the reference to the timer object
            this.oTimer = oBranch.oTimer;
            
            % Setting the reference to the branch object in which this flow
            % is contained.
            this.oBranch = oBranch;
        end
        
        function this = update(this, fCurrent, fVoltage)
            % UPDATE Updates the voltage and current properties
            %   This method is called as a result of the electrical solver
            %   completing its calculations.
            this.fCurrent = fCurrent;
            this.fVoltage = fVoltage;
        end
        
        
        function hRemoveIfComponent = seal(this, bIf, oBranch)
            %SEAL Seals the flow to prevent changes
            %   The method returns a function handle that removes the flow
            %   from an attached component in case it is an interface to a
            %   higher or lower subsystem.
            
            % Throw an error if we are already sealed
            if this.bSealed
                this.throw('seal', 'Already sealed!');
            end
            
            % Initializing the removal function handle
            hRemoveIfComponent = [];
            
            % Setting the sealed property to true
            this.bSealed = true;
            
            % Checking if this is actually an interface and if so, setting
            % the return parameter and property accordingly.
            if ~isempty(this.oIn) && isempty(this.oOut) && (nargin > 1) && bIf
                this.bInterface = true;
                hRemoveIfComponent   = @this.removeInterfaceComponent;
            end
            
            % Setting the reference to this flow's branch object
            if nargin > 2
                this.oBranch = oBranch; 
            end
        end
        
        
        function delete(this)
            %DELETE Removes references to the In/Out component, also tells that component about it, if it still exists.
            
            if ~isempty(this.oIn)  && isvalid(this.oIn),  this.thRemoveCBs.in(); end
            if ~isempty(this.oOut) && isvalid(this.oOut), this.thRemoveCBs.out(); end
            
            this.oIn = [];
            this.oOut = [];
        end
    end
    
    
    
    
    %% Sealed to ensure flow/f2f proc behaviour
    methods (Sealed = true)
        
        function addComponent(this, oComponent, removeCallBack)
            % ADDCOMPONENT Adds the provided component 
            %   The added component has to derive from
            %   electrical.component. 
            
            % Is the component of right type?
            if ~isa(oComponent, 'electrical.component')
                this.throw('addComponent', 'Provided component is not a or does not derive from electrical.component!');
                
            % Ensures that a flow can only be added through component
            % addFlow() methods, since aoFlows attribute has SetAccess
            % private!
            if ~any(oComponent.aoFlows == this)
                this.throw('addComponent', 'Object component aoFlows property is not the same as this one - use component''s addFlow method!');
            end
            
            % If sealed, can only do if also an interface. Additional check
            % for oIn just to make sure only oOut can be reconnected.
            elseif this.bSealed && (~this.bInterface || isempty(this.oIn))
                this.throw('addComponent', 'Can''t create branches any more, sealed.');
            end
            
            % If the oIn property is empty, we add the component there,
            % otherwise we add it as oOut and if both are not empty,
            % something went wrong. 
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
        
    end
    
    
    %% Methods to set properties, accessible through handles
    % See above, handles are returned when adding components or on .seal()
    methods (Access = protected)
        
        function removeInterfaceComponent(this)
            %REMOVEINTERFACECOMPONENT Decouples flow from component - only possible if interface flow!
            
            % Checking if this is an interface flow at all
            if ~this.bInterface
                this.throw('removeInterfaceComponent', 'Can only be done for interface flows.');
            
            % Checking if the oOut property has something to be removed
            elseif isempty(this.oOut)
                this.throw('removeInterfaceComponent', 'Not connected.');
                
            end
            
            % Executing the remove callbacks
            this.thRemoveCBs.out();
            
            % Deleting the remove callbacks
            this.thRemoveCBs.out = [];
            
            % Deleting the reference to the out component
            this.oOut = [];
        end
    end
    
end

