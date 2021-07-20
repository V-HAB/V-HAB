function tCurrentSystem = createThermalStructure(tCurrentSystem, csPhases, sSystemFile)

    fprintf(sSystemFile, '\n');
    fprintf(sSystemFile, '     	function createThermalStructure(this)\n');
    fprintf(sSystemFile, '          createThermalStructure@vsys(this);\n');
    
    %% Create heatsources
    for iStore = 1:length(tCurrentSystem.Stores)

        tStore = tCurrentSystem.Stores{iStore};

        for iPhaseType = 1:length(csPhases)
            sPhase = (csPhases{iPhaseType});

            for iPhase = 1:length(tStore.(sPhase))

                tPhase = tStore.(sPhase){iPhase};

                for iHeatSource = 1:length(tPhase.HeatSource)
                    tHeatSource = tPhase.HeatSource{iHeatSource};

                    fprintf(sSystemFile, '\n');

                    if isempty(tHeatSource.label)
                        tHeatSource.label = [tPhase.label, '_HeatSource_', num2str(iHeatSource)];
                    end

                    if strcmp(tHeatSource.sHeatSourceType, 'components.thermal.heatsources.ConstantTemperature')
                        fprintf(sSystemFile, ['oHeatSource = ', tHeatSource.sHeatSourceType, '(''', tHeatSource.label,''');\n']);
                    else
                        fprintf(sSystemFile, ['oHeatSource = ', tHeatSource.sHeatSourceType, '(''', tHeatSource.label,''', ', tHeatSource.fHeatFlow,');\n']);
                    end
                    fprintf(sSystemFile, ['this.toStores.', tStore.label,'.toPhases.', tPhase.label,'.oCapacity.addHeatSource(oHeatSource);\n']);
                end
            end
        end
    end
    
    fprintf(sSystemFile, '\n');
    
    for iHuman = 1:length(tCurrentSystem.Human)
        tHuman = tCurrentSystem.Human{iHuman};
        fprintf(sSystemFile, ['this.toChildren.' ,tHuman.label, '.createHumanHeatSource();\n']);
    end
    
    fprintf(sSystemFile, '\n');
    for iCDRA = 1:length(tCurrentSystem.CDRA)
        tCDRA = tCurrentSystem.CDRA{iCDRA};
        
        csReference = strsplit(tCDRA.ReferencePhase, '.');
        fprintf(sSystemFile, ['this.toChildren.' ,tCDRA.label, '.setReferencePhase(this.toStores.', csReference{1},'.toPhases.', csReference{2},');\n']);
    end
    
    fprintf(sSystemFile, '\n');
    fprintf(sSystemFile, '     	end\n');
end