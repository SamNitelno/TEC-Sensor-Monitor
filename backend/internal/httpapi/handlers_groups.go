package httpapi

import (
	"context"
	"net/http"

	"tek-sensor-monitor/backend/internal/service"
)

type contextT = context.Context

func (a *API) listWorkshops(c *rc) (int, any, error) {
	if _, err := c.viewer(); err != nil {
		return 0, nil, err
	}
	resp, err := a.svc.ListWorkshops(c.r.Context())
	return http.StatusOK, resp, err
}

func (a *API) createWorkshop(c *rc) (int, any, error) {
	if err := c.readBody(); err != nil {
		return 0, nil, err
	}
	if _, err := c.admin(); err != nil {
		return 0, nil, err
	}
	b := c.object()
	name, _ := b.str("name", true, false, 1, 255)
	color := b.color("color")
	if err := c.checkValidation(); err != nil {
		return 0, nil, err
	}
	resp, err := a.svc.CreateWorkshop(c.r.Context(), *name, color)
	return http.StatusCreated, resp, err
}

func (a *API) updateWorkshop(c *rc) (int, any, error) {
	if err := c.readBody(); err != nil {
		return 0, nil, err
	}
	if _, err := c.admin(); err != nil {
		return 0, nil, err
	}
	id := c.pathInt("workshop_id")
	b := c.object()
	var req service.WorkshopUpdateRequest
	req.Name, _ = b.str("name", false, true, 1, 255)
	req.Color = b.color("color")
	req.ClearColor = b.boolean("clear_color", false)
	req.NotificationsEnabled = b.optBool("notifications_enabled")
	if err := c.checkValidation(); err != nil {
		return 0, nil, err
	}
	resp, err := a.svc.UpdateWorkshop(c.r.Context(), id, req)
	return http.StatusOK, resp, err
}

func (a *API) deleteWorkshop(c *rc) (int, any, error) {
	if _, err := c.admin(); err != nil {
		return 0, nil, err
	}
	id := c.pathInt("workshop_id")
	if err := c.checkValidation(); err != nil {
		return 0, nil, err
	}
	if err := a.svc.DeleteWorkshop(c.r.Context(), id); err != nil {
		return 0, nil, err
	}
	return http.StatusNoContent, nil, nil
}

func (a *API) listSites(c *rc) (int, any, error) {
	if _, err := c.viewer(); err != nil {
		return 0, nil, err
	}
	workshopID := c.queryInt("workshop_id")
	if err := c.checkValidation(); err != nil {
		return 0, nil, err
	}
	resp, err := a.svc.ListSites(c.r.Context(), workshopID)
	return http.StatusOK, resp, err
}

func (a *API) createSite(c *rc) (int, any, error) {
	if err := c.readBody(); err != nil {
		return 0, nil, err
	}
	if _, err := c.admin(); err != nil {
		return 0, nil, err
	}
	b := c.object()
	name, _ := b.str("name", true, false, 1, 255)
	workshopID, _ := b.integer("workshop_id", true, nil)
	color := b.color("color")
	if err := c.checkValidation(); err != nil {
		return 0, nil, err
	}
	resp, err := a.svc.CreateSite(c.r.Context(), *name, *workshopID, color)
	return http.StatusCreated, resp, err
}

func (a *API) updateSite(c *rc) (int, any, error) {
	if err := c.readBody(); err != nil {
		return 0, nil, err
	}
	if _, err := c.admin(); err != nil {
		return 0, nil, err
	}
	id := c.pathInt("site_id")
	b := c.object()
	var req service.SiteUpdateRequest
	req.Name, _ = b.str("name", false, true, 1, 255)
	req.WorkshopID, _ = b.integer("workshop_id", false, nil)
	req.Color = b.color("color")
	req.ClearColor = b.boolean("clear_color", false)
	req.NotificationsEnabled = b.optBool("notifications_enabled")
	if err := c.checkValidation(); err != nil {
		return 0, nil, err
	}
	resp, err := a.svc.UpdateSite(c.r.Context(), id, req)
	return http.StatusOK, resp, err
}

func (a *API) deleteSite(c *rc) (int, any, error) {
	if _, err := c.admin(); err != nil {
		return 0, nil, err
	}
	id := c.pathInt("site_id")
	if err := c.checkValidation(); err != nil {
		return 0, nil, err
	}
	if err := a.svc.DeleteSite(c.r.Context(), id); err != nil {
		return 0, nil, err
	}
	return http.StatusNoContent, nil, nil
}
