classdef convective < thermal.procs.conductor
    % a general conductor for convective heat transfer, this does not work
    % on its own, you have to create a child class of this and implement
    % the function updateHeatTransferCoefficient for it. As this is very
    % dependant on the use case it cannot be defined generally
    
    properties (SetAccess = protected)
        % Thermal resistance of connection in [K/W].
        fResistance = 0; 

        % Area of heat transfer
        fArea; % [m^2]
        
        % also known as alpha in most literature
        fHeatTransferCoefficient = 0; % [W/m^2 K]
        
        % Reference to the matter branch modelling the flow which results
        % in convective heat transfer
        oMassBranch;
        
        % number of the flow within oMassBranch which is modelled, used to
        % calculate the matter properties for the heat transfer
        iFlow;
        
        % Check if we are outdated or not to decide if a post tick update
        % is necessary
        bSetOutdated = false;
    end
    
    methods
        
        function this = convective(oContainer, sName, fArea, oMassBranch, iFlow)
            % Create a convective conductor to calculate convective heat
            % transfer. The required inputs are:
            % oContainer:       The system in which the conductor is placed
            % sName:            A name for the conductor which is not
            %                   shared by other conductors within oContainer
            % fArea:            Area of the heat transfer in m^2
            % oMassBranch:      The matter branch which models the mass
            %                   flow through the pipe
            % iFlow:            The number of the flow  within this branch
            %                   which should be modelled by this conductor
            %                   (necessary for matter properties)
            
            % Calling the parent constructor
            this@thermal.procs.conductor(oContainer, sName);
            
            % Setting the conductor type to convective
            this.bConvective = true;
            
            this.fArea = fArea;
            this.oMassBranch = oMassBranch;
            this.iFlow = iFlow;
            
            % necessary for the convective conductor to realise that the
            % mass flow rate has changed
            this.oMassBranch.bind('setFlowRate',@(~)this.setOutdated());
        end
        
        function fResistance = update(this, ~)
            % Update the thermal resistance of this conductor. For this the
            % updateHeatTransferCoefficient function must be implemented in
            % the subclass to allow recalculation for this specific use
            % case
            this.fHeatTransferCoefficient = this.updateHeatTransferCoefficient();
            
            % With the heat transfer coefficient we can now update the
            % thermal resistance
            fResistance = 1 / (this.fHeatTransferCoefficient * this.fArea);
            
            this.fResistance = fResistance;
            
            % Once this is done we are no longer outdated
            this.bSetOutdated = false;
        end
        
        function setOutdated(this,~)
            % the setOutdated function is used to inform the thermal branch
            % that this conductor needs to be recalculated, which requires
            % the branch to update itself
            if ~this.bSetOutdated
                this.oThermalBranch.setOutdated();
                this.bSetOutdated = true;
            end 
        end
    end
    
    % Abstract methods are not implemented in the supraclass but are
    % mandatory for all subclasses inheriting from this class to implement.
    methods (Abstract = true)
        updateHeatTransferCoefficient(this)
    end
end