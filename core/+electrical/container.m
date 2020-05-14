classdef (Abstract) container < sys
    %CONTAINER A system that contains electrical objects
    %   Container is the base class of the electrical domain in V-HAB. It
    %   contains the circuits and provides methods for adding them. 
    
    properties (SetAccess = protected, GetAccess = public)
        % An array containing all circuits of this electrical system
        aoCircuits;
        
        % A struct containing all circuits of this electrical system
        toCircuits = struct();
        
        % A cell containing the names of all the circuits of this
        % electrical system
        csCircuits;
        
        % Indicator if this container is sealed or not
        bElectricalSealed;
    
    end
    
    methods
        function this = container(oParent, sName)
            % Calling the parent constructor
            this@sys(oParent, sName);
            
            this.aoCircuits = electrical.circuit.empty();
            
        end
    end
        
    
    methods (Access = public)
        
        function createElectricalStructure(this)
            %CREATELECTRICALSTRUCTURE Calls this function on all child objects
            %   This method will contain the definiton of the electrical
            %   system in the classes that inherit from this class. The
            %   only thing we have to do here is therefore to call it on
            %   all child objects.
            
            % Getting the names of all child systems
            csChildren = fieldnames(this.toChildren);
            
            % Looping through all children and calling
            % createElectricalStructure().
            for iC = 1:length(csChildren)
                sChild = csChildren{iC};
                this.toChildren.(sChild).createElectricalStructure();
                
            end
        end
        
        function addCircuit(this, oCircuit)
            %ADDCIRCUIT Adds the provided circuit to the container
            this.toCircuits.(oCircuit.sName) = oCircuit;
            this.aoCircuits(end + 1) = oCircuit;
        end

        
        function sealElectricalStructure(this)
            %SEALELECTRICALSTRUCTURE Seals all circuits in this container and calls this method on any subsystems
            
            % If this container is already sealed, something went wrong.
            if this.bElectricalSealed
                this.throw('sealElectricalStructure', 'Already sealed');
            end
            
            % Getting the names of all child containers
            csChildren = fieldnames(this.toChildren);
            
            % Looping through all children and calling
            % sealElectricalStructure().
            for iC = 1:length(csChildren)
                sChild = csChildren{iC};
                this.toChildren.(sChild).sealElectricalStructure();
                
            end
            
            % Getting the names of all circuits and setting the csCircuits
            % property accordingly
            this.csCircuits = fieldnames(this.toCircuits);
            
            % Looping through all circuits and calling their seal() method.
            for iI = 1:length(this.csCircuits)
                this.toCircuits.(this.csCircuits{iI}).seal();
                
            end
            
            % Setting the sealed property to true
            this.bElectricalSealed = true;
        end
        
    end
    
end

