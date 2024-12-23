secure-invoke-test:
	@echo -e "\e[34m$@\e[0m" || true
	scripts/secure-invoke-test.sh $(filter-out $@,$(MAKECMDGOALS))
	