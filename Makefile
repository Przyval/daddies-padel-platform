.PHONY: help get analyze test build-web deploy-staging deploy-prod clean

# Default target
help:
	@echo "Daddies Padel Platform — Dev Commands"
	@echo ""
	@echo "  make get             Install dependencies"
	@echo "  make analyze         Run Dart static analysis"
	@echo "  make test            Run all tests"
	@echo "  make build-web       Build Flutter Web (release)"
	@echo "  make deploy-staging  Deploy to Firebase staging channel"
	@echo "  make deploy-prod     Deploy to Firebase live (production)"
	@echo "  make clean           Remove build artifacts"

get:
	flutter pub get

analyze:
	flutter analyze

test:
	flutter test --coverage

build-web:
	flutter build web --release

deploy-staging: build-web
	firebase hosting:channel:deploy staging --expires 7d --project padel-daddies

deploy-prod: build-web
	firebase deploy --only hosting --project padel-daddies

clean:
	flutter clean
	rm -rf build/
