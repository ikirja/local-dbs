.PHONY: up down restart ps logs mongo reset

up:            ## Start all databases, wait until healthy
	docker compose up -d --wait

down:          ## Stop all databases (keep data)
	docker compose down

restart:       ## Restart all databases
	docker compose restart

ps:            ## Show container status (health column)
	docker compose ps

logs:          ## Follow all logs
	docker compose logs -f

mongo:         ## Open mongosh shell in the container
	docker compose exec mongo mongosh

reset:         ## Stop and delete ALL data (destructive)
	docker compose down -v